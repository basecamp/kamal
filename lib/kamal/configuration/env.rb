class Kamal::Configuration::Env
  include Kamal::Configuration::Validation

  attr_reader :context
  attr_reader :clear, :secret_keys
  delegate :argumentize, to: Kamal::Utils

  def initialize(config:, secrets:, context: "env")
    @clear = config.fetch("clear", config.key?("secret") || config.key?("tags") ? {} : config)
    @secrets = secrets
    @secret_keys = config.fetch("secret", [])
    @context = context
    validate! config, context: context, with: Kamal::Configuration::Validator::Env
    @secret_map = build_secret_map(@secret_keys)
  end

  def clear_args
    argumentize("--env", clear)
  end

  def secrets
    @resolved_secrets ||= resolve_secrets
  end

  def secrets_io
    Kamal::EnvFile.new(secrets).to_io
  end

  def merge(other)
    self.class.new \
      config: { "clear" => clear.merge(other.clear), "secret" => secret_keys | other.secret_keys },
      secrets: @secrets
  end

  private
    def build_secret_map(secret_keys)
      Array(secret_keys).to_h do |key|
        key_name, key_aliased_to = key.split(":", 2)
        key_aliased_to ||= key_name
        [ key_name, key_aliased_to ]
      end
    end

    def resolve_secrets
      @secret_map.transform_values { |secret_key| @secrets[secret_key] }
    end
end
