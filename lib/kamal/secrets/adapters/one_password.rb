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

    def fetch_secrets(secrets, from:, account:, session:)
      if secrets.blank?
        fetch_all_secrets(from: from, account: account, session: session) if secrets.blank?
      else
        fetch_specified_secrets(secrets, from: from, account: account, session: session)
      end
    end

    def fetch_specified_secrets(secrets, from:, account:, session:)
      {}.tap do |results|
        vaults_items_fields(prefixed_secrets(secrets, from: from)).map do |vault, items|
          items.each do |item, fields|
            fields_json = JSON.parse(op_item_get(vault, item, fields: fields, account: account, session: session))
            fields_json = [ fields_json ] if fields.one?

            results.merge!(fields_map(fields_json))
          end
        end
      end
    end

    def fetch_all_secrets(from:, account:, session:)
      {}.tap do |results|
        vault_items(from).each do |vault, items|
          items.each do |item|
            fields_json = JSON.parse(op_item_get(vault, item, account: account, session: session)).fetch("fields")

            results.merge!(fields_map(fields_json))
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

    def vault_items(from)
      from = from.delete_prefix("op://")
      vault, item = from.split("/")
      { vault => [ item ] }
    end

    def fields_map(fields_json)
      fields_json.to_h do |field_json|
        # The reference is in the form `op://vault/item/field[/field]`
        field = field_json["reference"].delete_prefix("op://").delete_suffix("/password")
        [ field, field_json["value"] ]
      end
    end

    def op_item_get(vault, item, fields: nil, account:, session:)
      options = { vault: vault, format: "json", account: account, session: session.presence }

      if fields.present?
        labels = fields.map { |field| "label=#{field}" }.join(",")
        options.merge!(fields: labels)
      end

      `op item get #{item.shellescape} #{to_options(**options)}`.tap do
        raise RuntimeError, "Could not read #{"#{fields.join(", ")} " if fields.present?}from #{item} in the #{vault} 1Password vault" unless $?.success?
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
