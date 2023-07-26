class Mrsk::Configuration::Sshkit
  def initialize(config:)
    @options = config.raw_config.sshkit || {}
  end

  def max_concurrent_starts
    options.fetch("max_concurrent_starts", 30)
  end

  def pool_idle_timeout
    options.fetch("pool_idle_timeout", 900)
  end

  def to_h
    options
  end

  private
    attr_accessor :options
end
