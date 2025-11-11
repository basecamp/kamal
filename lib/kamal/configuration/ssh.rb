class Kamal::Configuration::Ssh
  LOGGER = ::Logger.new(STDERR)

  include Kamal::Configuration::Validation

  attr_reader :ssh_config, :secrets

  def initialize(config:)
    @ssh_config = config.raw_config.ssh || {}
    @secrets = config.secrets
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

  def keys_only
    ssh_config["keys_only"]
  end

  def keys
    ssh_config["keys"]
  end

  def key_data
    key_data = ssh_config["key_data"]
    return unless key_data

    key_data.map do |k|
      if secrets.key?(k)
        secrets[k]
      else
        warn "Inline key_data usage is deprecated and will be removed in Kamal 3. Please store your key_data in a secret."
        k
      end
    end
  end

  def config
    ssh_config["config"]
  end

  def options
    { user: user, port: port, proxy: proxy, logger: logger, keepalive: true, keepalive_interval: 30, keys_only: keys_only, keys: keys, key_data: key_data, config: config  }.compact
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
