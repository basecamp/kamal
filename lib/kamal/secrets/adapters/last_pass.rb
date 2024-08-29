class Kamal::Secrets::Adapters::LastPass < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      unless loggedin?(account)
        `lpass login #{account}`
        raise RuntimeError, "Failed to login to 1Password" unless $?.success?
      end
    end

    def loggedin?(account)
      `lpass status --color never`.strip == "Logged in as #{account}."
    end

    def fetch_from_vault(secrets, account:, session:)
      items = JSON.parse(`lpass show #{secrets.join(" ")} --json`
      raise RuntimeError, "Could not read #{fields} from 1Password" unless $?.success?

      {}.tap do |results|
        items.each do |item|
          results[item["name"]] = item["password"]
          results[item["fullname"]] = item["password"]
        end

        if (missing_items = secrets - results.keys).any?
          raise RuntimeError, "Could not find #{missing_items.join(", ")} in LassPass"
        end
      end
    end
end
