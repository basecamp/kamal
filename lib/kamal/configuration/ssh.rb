class Kamal::Configuration::Ssh
  LOGGER = ::Logger.new(STDERR)

  include Kamal::Configuration::Validation

  attr_reader :ssh_config

  def initialize(config:)
    @ssh_config = config.raw_config.ssh || {}
    validate! ssh_config
  end

  def user
    ssh_config.fetch("user", "root")
  end

  def port
    ssh_config.fetch("port", 22)
  end

  def proxy
    if (proxy = ssh_config["proxy"])
      Net::SSH::Proxy::Jump.new(proxy.include?("@") ? proxy : "root@#{proxy}")
    elsif (proxy_command = ssh_config["proxy_command"])
      Net::SSH::Proxy::Command.new(proxy_command)
    end
  end

  def options
    { user: user, port: port, proxy: proxy, logger: logger, keepalive: true, keepalive_interval: 30 }.compact
  end

  def to_h
    options.except(:logger).merge(log_level: log_level)
  end

  private
    def logger
      LOGGER.tap { |logger| logger.level = log_level }
    end

    def log_level
      ssh_config.fetch("log_level", :fatal)
    end
end
