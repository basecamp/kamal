class Kamal::Configuration::Env::Tag
  attr_reader :name, :config, :secrets

  def initialize(name, config:, secrets:)
    @name = name
    @config = config
    @secrets = secrets
  end

  def env
    Kamal::Configuration::Env.new(config: config, secrets: secrets)
  end
end
