class Kamal::Configuration::Loadbalancer < Kamal::Configuration::Proxy
  CONTAINER_NAME = "load-balancer".freeze

  def self.validation_config_key
    "proxy"
  end

  def initialize(config:, proxy_config:)
    super(config: config, proxy_config: proxy_config)
  end

  def deploy_options
    opts = super

    opts[:host] = hosts if hosts.present?
    opts[:tls] = proxy_config["ssl"].presence

    opts
  end

  def directory
    File.join config.run_directory, "loadbalancer"
  end

  def container_name
    CONTAINER_NAME
  end
end
