class Kamal::Configuration::Env
  include Kamal::Configuration::Validation

  attr_reader :context, :clear, :secret_keys
  delegate :argumentize, to: Kamal::Utils

  def initialize(config:, secrets:, context: "env")
    @clear = config.fetch("clear", config.key?("secret") || config.key?("tags") ? {} : config)
    @secrets = secrets
    @secret_keys = config.fetch("secret", [])
    @context = context
    validate! config, context: context, with: Kamal::Configuration::Validator::Env
  end

  def clear_args
    argumentize("--env", clear)
  end

  def secrets_io
    Kamal::EnvFile.new(aliased_secrets).to_io
  end

  def merge(other)
    self.class.new \
      config: { "clear" => clear.merge(other.clear), "secret" => secret_keys | other.secret_keys },
      secrets: @secrets
  end

  private
    def aliased_secrets
      secret_keys.to_h { |key| extract_alias(key) }.transform_values { |secret_key| @secrets[secret_key] }
    end

    def extract_alias(key)
      key_name, key_aliased_to = key.split(":", 2)
      [ key_name, key_aliased_to || key_name ]
    end
end
