class Kamal::Configuration::Env
  attr_reader :secrets_keys, :clear, :secrets_file, :env_file
  delegate :argumentize, to: Kamal::Utils

  def self.from_config(config:, secrets_file: nil)
    env_key_config = config.class == Kamal::Configuration ? config.env : config.fetch("env", {})
    secrets_keys = env_key_config.fetch("secret", [])
    clear = env_key_config.fetch("clear", env_key_config.key?("secret") || env_key_config.key?("tags") ? {} : env_key_config)
    # TODO: Support a wide env_file
    env_file = config.class == Kamal::Configuration ? nil : config.fetch("env_file", nil)

    new clear: clear, secrets_keys: secrets_keys, secrets_file: secrets_file, env_file: env_file
  end

  def initialize(clear:, secrets_keys:, secrets_file:, env_file:)
    @clear = clear
    @secrets_keys = secrets_keys
    @secrets_file = secrets_file
    @env_file = env_file
  end

  def args
    [ "--env-file", secrets_file, *argumentize("--env", clear) ]
  end

  def secrets_io
    StringIO.new(Kamal::EnvFile.new(secrets).to_s)
  end

  def secrets
    # TODO: More than one @env_file
    # TODO: Considerer a merge between env_file and env
    if @env_file
      Dotenv::Environment.new(@env_file)
    else
      secrets_keys.to_h { |key| [ key, ENV.fetch(key) ] }
    end
  end

  def secrets_directory
    File.dirname(secrets_file)
  end

  def merge(other)
    self.class.new \
      clear: @clear.merge(other.clear),
      secrets_keys: @secrets_keys | other.secrets_keys,
      env_file: @env_file ? @env_file : other.env_file,
      secrets_file: secrets_file
  end
end
