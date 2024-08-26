class Kamal::Secrets::Adapters::OnePassword
  delegate :optionize, to: Kamal::Utils

  def fetch(item, fields, account: nil)
    # session may be nil if logging in with the app CLI integration
    session = signin(account)
    vault, vault_item = item.split("/")
    labels = fields.map { |field| "label=#{field}" }.join(",")
    options = to_options(vault: vault, fields: labels, format: "json", account: account, session: session.presence)

    secrets_json = `op item get #{vault_item} #{options}`.tap do
      raise RuntimeError, "Could not read #{labels} from #{vault_item} in the #{vault} 1Password vault" unless $?.success?
    end

    {}.tap do |secrets|
      JSON.parse(secrets_json).each do |secret_json|
        # The reference is in the form `op://vault/item/field[/field]`
        field = secret_json["reference"].delete_prefix("op://#{item}/")
        secrets[field] = secret_json["value"]
        secrets[field.split("/").last] = secret_json["value"]
      end
    end
  rescue => e
    $stderr.puts "  \e[31mERROR (#{e.class}): #{e.message}\e[0m"

    Process.kill("INT", Process.ppid) if ENV["KAMAL_SECRETS_KILL_PARENT"]
    exit 1
  end

  private
    def signin(account)
      `op signin #{to_options(account: account, force: true, raw: true)}`.tap do
        raise RuntimeError, "Failed to login to 1Password" unless $?.success?
      end
    end

    def to_options(**options)
      optionize(options.compact).join(" ")
    end
end
