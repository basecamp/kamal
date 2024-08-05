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

  def args
    [ *clear_args, *secret_args ]
  end

  def merge(other)
    self.class.new \
      config: { "clear" => clear.merge(other.clear), "secret" => secret_keys | other.secret_keys },
      secrets: secrets
  end

  private
    def clear_args
      argumentize("--env", clear)
    end

    def secret_args
      argumentize("--env", secret_keys.to_h { |key| [ key, secrets[key] ] }, sensitive: true)
    end
end
