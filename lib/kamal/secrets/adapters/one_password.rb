class Kamal::Secrets::Adapters::OnePassword < Kamal::Secrets::Adapters::Base
  delegate :optionize, to: Kamal::Utils

  private
    def login(account)
      unless loggedin?(account)
        `op signin #{to_options(account: account, force: true, raw: true)}`.tap do
          raise RuntimeError, "Failed to login to 1Password" unless $?.success?
        end
      end
    end

    def loggedin?(account)
      `op account get --account #{account.shellescape} 2> /dev/null`
      $?.success?
    end

    def fetch_secrets(secrets, account:, session:)
      {}.tap do |results|
        vaults_items_fields(secrets).map do |vault, items|
          items.each do |item, fields|
            fields_json = JSON.parse(op_item_get(vault, item, fields, account: account, session: session))
            fields_json = [ fields_json ] if fields.one?

            fields_json.each do |field_json|
              # The reference is in the form `op://vault/item/field[/field]`
              field = field_json["reference"].delete_prefix("op://").delete_suffix("/password")
              results[field] = field_json["value"]
            end
          end
        end
      end
    end

    def to_options(**options)
      optionize(options.compact).join(" ")
    end

    def vaults_items_fields(secrets)
      {}.tap do |vaults|
        secrets.each do |secret|
          secret = secret.delete_prefix("op://")
          vault, item, *fields = secret.split("/")
          fields << "password" if fields.empty?

          vaults[vault] ||= {}
          vaults[vault][item] ||= []
          vaults[vault][item] << fields.join(".")
        end
      end
    end

    def op_item_get(vault, item, fields, account:, session:)
      labels = fields.map { |field| "label=#{field}" }.join(",")
      options = to_options(vault: vault, fields: labels, format: "json", account: account, session: session.presence)

      `op item get #{item.shellescape} #{options}`.tap do
        raise RuntimeError, "Could not read #{fields.join(", ")} from #{item} in the #{vault} 1Password vault" unless $?.success?
      end
    end

    def check_dependencies!
      raise RuntimeError, "1Password CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `op --version 2> /dev/null`
      $?.success?
    end
end
