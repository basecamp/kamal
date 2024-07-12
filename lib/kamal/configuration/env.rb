class Kamal::Configuration::Env
  include Kamal::Configuration::Validation

  attr_reader :secrets_keys, :clear, :secrets_file, :context
  delegate :argumentize, to: Kamal::Utils

  def initialize(config:, secrets_file: nil, context: "env")
    @clear = config.fetch("clear", config.key?("secret") || config.key?("tags") ? {} : config)
    @secrets_keys = config.fetch("secret", [])
    @secrets_file = secrets_file
    @context = context
    validate! config, context: context, with: Kamal::Configuration::Validator::Env
  end

  def args
    [ "--env-file", secrets_file, *argumentize("--env", clear) ]
  end

  def secrets_io
    StringIO.new(Kamal::EnvFile.new(secrets).to_s)
  end

  def secrets
    @secrets ||= secrets_keys.to_h { |key| [ key, ENV.fetch(key) ] }
  end

  def secrets_directory
    File.dirname(secrets_file)
  end

  def merge(other)
    self.class.new \
      config: { "clear" => clear.merge(other.clear), "secret" => secrets_keys | other.secrets_keys },
      secrets_file: secrets_file || other.secrets_file
  end
end
