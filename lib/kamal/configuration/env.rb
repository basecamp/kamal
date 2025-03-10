class Kamal::Configuration::Env
  include Kamal::Configuration::Validation

  attr_reader :context, :secrets
  attr_reader :clear, :secret_keys
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
    Kamal::EnvFile.new(secrets_hash).to_io
  end

  def merge(other)
    self.class.new \
      config: { "clear" => clear.merge(other.clear), "secret" => secret_keys | other.secret_keys },
      secrets: secrets
  end

  private
    def secrets_hash
      secret_keys.to_h do |key|
        key_name, key_aliased_to = key.split(":")
        [ key_name, secrets[key_aliased_to || key_name] ]
      end
    end
end
