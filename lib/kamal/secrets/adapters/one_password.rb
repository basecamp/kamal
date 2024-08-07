class Kamal::Secrets::Adapters::OnePassword
  delegate :optionize, to: Kamal::Utils

  def login(account:)
    `op signin #{to_options(account: account, force: true, raw: true)}`.tap do
      raise RuntimeError, "Failed to login to 1Password: #{output}" unless $?.success?
    end
  end

  def fetch(name, account:, session: nil)
    `op read #{name} #{to_options(account: account, session: session)}`.tap do
      raise RuntimeError, "Could not read #{name} from 1Password" unless $?.success?
    end
  end

  def fetch_all(*names, account:, session: nil)
    secrets = {}

    vaults_items_fields(names).each do |vault, items|
      items.each do |item, fields|
        labels = fields.map { |field| "label=#{field}" }.join(",")
        secrets_json = `op item get #{item} #{to_options(vault: vault, fields: labels, format: "json", account: account, session: session.presence)}`.tap do
          raise RuntimeError, "Could not read #{labels} from #{item} in the #{vault} 1Password vault" unless $?.success?
        end

        JSON.parse(secrets_json).each do |secret_json|
          secrets[secret_json["reference"]] = secret_json["value"]
        end
      end
    end

    secrets
  end

  private
    def vaults_items_fields(names)
      {}.tap do |vaults|
        names.each do |name|
          vault, item, field = vault_item_field(name)
          vaults[vault] ||= {}
          vaults[vault][item] ||= []
          vaults[vault][item] << field
        end
      end
    end

    def vault_item_field(name)
      parts = name.delete_prefix("op://").split("/")

      [ parts[0], parts[1], parts[2..-1].join(".") ]
    end

    def to_options(**options)
      optionize(options.compact).join(" ")
    end
end
