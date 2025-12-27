class Kamal::Configuration::Loadbalancer < Kamal::Configuration::Proxy
  CONTAINER_NAME = "load-balancer".freeze
  SHARED_CONTAINER_NAME = "kamal-proxy".freeze

  def self.validation_config_key
    "proxy"
  end

  def initialize(config:, proxy_config:, secrets:)
    super
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
    on_proxy_host? ? SHARED_CONTAINER_NAME : CONTAINER_NAME
  end

  # When loadbalancer is on a proxy host, it takes over the proxy role
  def on_proxy_host?
    config.proxy_hosts.include?(config.proxy.effective_loadbalancer)
  end
end
