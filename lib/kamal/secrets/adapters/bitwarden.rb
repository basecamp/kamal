class Kamal::Secrets::Adapters::Bitwarden < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      status = run_command("status")

      if status["status"] == "unauthenticated"
        run_command("login #{account}")
        status = run_command("status")
      end

      if status["status"] == "locked"
        session = run_command("unlock --raw", raw: true)
        status = run_command("status", session: session)
      end

      raise RuntimeError, "Failed to login to and unlock Bitwarden" unless status["status"] == "unlocked"

      run_command("sync", raw: true)
      raise RuntimeError, "Failed to sync Bitwarden" unless $?.success?

      session
    end

    def fetch_from_vault(secrets, account:, session:)
      {}.tap do |results|
        secrets.each do |secret|
          item, field = secret.split("/")
          item = run_command("get item #{item}", session: session)
          raise RuntimeError, "Could not read #{item} from Bitwarden" unless $?.success?
          if field
            item_field = item["fields"].find { |f| f["name"] == field }
            raise RuntimeError, "Could not find field #{field} in item #{item} in Bitwarden" unless item_field
            value = item_field["value"]
            results[secret] = value
            results[field] = value
          else
            results[secret] = item["login"]["password"]
          end
        end
      end
    end

    def signedin?(account)
      JSON.parse(`bw status`.strip)["status"] != "unauthenticated"
    end

    def run_command(command, session: nil, raw: false)
      full_command = [ *("BW_SESSION=#{session}" if session), "bw", command ].join(" ")
      result = `#{full_command}`.strip
      raw ? result : JSON.parse(result)
    end
end
