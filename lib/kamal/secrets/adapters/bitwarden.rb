class Kamal::Secrets::Adapters::Bitwarden < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      status = run_command("status")

      if status["status"] == "unauthenticated"
        run_command("login #{account}")
        status = run_command("status")
      end

      if status["status"] == "locked"
        session = run_command("unlock --raw", raw: true).presence
        status = run_command("status", session: session)
      end

      raise RuntimeError, "Failed to login to and unlock Bitwarden" unless status["status"] == "unlocked"

      run_command("sync", session: session, raw: true)
      raise RuntimeError, "Failed to sync Bitwarden" unless $?.success?

      session
    end

    def fetch_from_vault(secrets, account:, session:)
      {}.tap do |results|
        items_fields(secrets).each do |item, fields|
          item_json = run_command("get item #{item}", session: session, raw: true)
          raise RuntimeError, "Could not read #{secret} from Bitwarden" unless $?.success?
          item_json = JSON.parse(item_json)

          if fields.any?
            fields.each do |field|
              item_field = item_json["fields"].find { |f| f["name"] == field }
              raise RuntimeError, "Could not find field #{field} in item #{item} in Bitwarden" unless item_field
              value = item_field["value"]
              results["#{item}/#{field}"] = value
            end
          else
            results[item] = item_json["login"]["password"]
          end
        end
      end
    end

    def items_fields(secrets)
      {}.tap do |items|
        secrets.each do |secret|
          item, field = secret.split("/")
          items[item] ||= []
          items[item] << field
        end
      end
    end

    def signedin?(account)
      run_command("status")["status"] != "unauthenticated"
    end

    def run_command(command, session: nil, raw: false)
      full_command = [ *("BW_SESSION=#{session}" if session), "bw", command ].join(" ")
      result = `#{full_command}`.strip
      raw ? result : JSON.parse(result)
    end
end