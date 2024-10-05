class Kamal::Secrets::Adapters::Bitwarden < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      status = run_command("status")

      if status["status"] == "unauthenticated"
        run_command("login #{account.shellescape}", raw: true)
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

    def fetch_secrets(secrets, account:, session:)
      {}.tap do |results|
        items_fields(secrets).each do |item, fields|
          item_json = run_command("get item #{item.shellescape}", session: session, raw: true)
          raise RuntimeError, "Could not read #{item} from Bitwarden" unless $?.success?
          item_json = JSON.parse(item_json)
          if fields.any?
            results.merge! fetch_secrets_from_fields(fields, item, item_json)
          elsif item_json.dig("login", "password")
            results[item] = item_json.dig("login", "password")
          elsif item_json["fields"]&.any?
            fields = item_json["fields"].pluck("name")
            results.merge! fetch_secrets_from_fields(fields, item, item_json)
          else
            raise RuntimeError, "Item #{item} is not a login type item and no fields were specified"
          end
        end
      end
    end

    def fetch_secrets_from_fields(fields, item, item_json)
      fields.to_h do |field|
        item_field = item_json["fields"].find { |f| f["name"] == field }
        raise RuntimeError, "Could not find field #{field} in item #{item} in Bitwarden" unless item_field
        value = item_field["value"]
        [ "#{item}/#{field}", value ]
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
      full_command = [ *("BW_SESSION=#{session.shellescape}" if session), "bw", command ].join(" ")
      result = `#{full_command}`.strip
      raw ? result : JSON.parse(result)
    end

    def check_dependencies!
      raise RuntimeError, "Bitwarden CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `bw --version 2> /dev/null`
      $?.success?
    end
end
