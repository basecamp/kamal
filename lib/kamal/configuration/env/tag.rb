class Kamal::Configuration::Env::Tag
  attr_reader :name, :config

  def initialize(name, config:)
    @name = name
    @config = config
  end

  def env
    Kamal::Configuration::Env.from_config(config: config, for_node: @name)
  end
end
