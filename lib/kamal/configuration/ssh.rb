class Kamal::Configuration::Ssh
  LOGGER = ::Logger.new(STDERR)

  include Kamal::Configuration::Validation

  attr_reader :ssh_config

  def initialize(config:, secrets:)
    @ssh_config = config.raw_config.ssh || {}
    @secrets = secrets
    validate! ssh_config, with: Kamal::Configuration::Validator::Ssh
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

  def keys_only
    ssh_config["keys_only"]
  end

  def keys
    ssh_config["keys"]
  end

  def key_data
    lookup("key_data")
  end

  def options
    { user: user, port: port, proxy: proxy, logger: logger, keepalive: true, keepalive_interval: 30, keys_only: keys_only, keys: keys, key_data: key_data }.compact
  end

  def to_h
    options.except(:logger).merge(log_level: log_level)
  end

  private
  attr_reader :secrets
    def logger
      LOGGER.tap { |logger| logger.level = log_level }
    end

    def log_level
      ssh_config.fetch("log_level", :fatal)
    end

    def lookup(key)
      if ssh_config[key].is_a?(String)
        secrets[ssh_config[key]]
      else
        ssh_config[key]
      end
    end
end
