class Kamal::Configuration::Ssh
  LOGGER = ::Logger.new(STDERR)

  def initialize(config:)
    @config = config.raw_config.ssh || {}
  end

  def user
    config.fetch("user", "root")
  end

  def port
    config.fetch("port", 22)
  end

  def proxy
    if (proxy = config["proxy"])
      Net::SSH::Proxy::Jump.new(proxy.include?("@") ? proxy : "root@#{proxy}")
    elsif (proxy_command = config["proxy_command"])
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
    attr_accessor :config

    def logger
      LOGGER.tap { |logger| logger.level = log_level }
    end

    def log_level
      config.fetch("log_level", :fatal)
    end
end
