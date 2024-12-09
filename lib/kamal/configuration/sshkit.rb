class Kamal::Configuration::Sshkit
  include Kamal::Configuration::Validation

  attr_reader :sshkit_config

  def initialize(config:)
    @sshkit_config = config.raw_config.sshkit || {}
    validate! sshkit_config, with: Kamal::Configuration::Validator::Sshkit
  end

  def max_concurrent_starts
    sshkit_config.fetch("max_concurrent_starts", 30)
  end

  def pool_idle_timeout
    sshkit_config.fetch("pool_idle_timeout", 900)
  end

  def default_env
    sshkit_config.fetch("default_env", {}).transform_keys(&:to_sym)
  end

  def to_h
    sshkit_config
  end
end
