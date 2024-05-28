class Kamal::Configuration::Env::Tag
  attr_reader :name, :config

  def initialize(name, config:)
    @name = name
    @config = config
  end

  def env
    Kamal::Configuration::Env.new(config: config)
  end
end
