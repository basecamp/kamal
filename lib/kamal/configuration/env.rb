class Kamal::Configuration::Env
  attr_reader :secrets_keys, :clear, :secrets_file
  delegate :argumentize, to: Kamal::Utils

  def self.from_config(config:, secrets_file: nil, for_node: nil)
    secrets_keys = config.fetch("secret", [])
    clear = config.fetch("clear", config.key?("secret") || config.key?("tags") ? {} : config)
    env_file = config.fetch("env_file", nil)

    new clear: clear, secrets_keys: secrets_keys, secrets_file: secrets_file, for_node: for_node, env_file: env_file
  end

  def initialize(clear:, secrets_keys:, secrets_file:, for_node:, env_file:)
    @clear = clear
    @secrets_keys = secrets_keys
    @secrets_file = secrets_file
    @for_node = for_node
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
      for_node: @for_node,
      env_file: @env_file,
      secrets_file: secrets_file
  end
end
