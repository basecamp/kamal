class Kamal::Configuration::Registry
  include Kamal::Configuration::Validation

  attr_reader :registry_config

  def initialize(config:)
    @registry_config = config.raw_config.registry || {}
    validate! registry_config, with: Kamal::Configuration::Validator::Registry
  end

  def server
    registry_config["server"]
  end

  def username
    lookup("username")
  end

  def password
    lookup("password")
  end

  private
    def lookup(key)
      if registry_config[key].is_a?(Array)
        ENV.fetch(registry_config[key].first).dup
      else
        registry_config[key]
      end
    end
end
