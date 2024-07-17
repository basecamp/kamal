class Kamal::Configuration::Proxy
  include Kamal::Configuration::Validation

  DEFAULT_HTTP_PORT = 80
  DEFAULT_HTTPS_PORT = 443
  DEFAULT_IMAGE = "basecamp/kamal-proxy:latest"

  delegate :argumentize, :optionize, to: Kamal::Utils

  def initialize(config:)
    @proxy_config = config.raw_config.proxy || {}
    validate! proxy_config
  end

  def enabled?
    !!proxy_config.fetch("enabled", false)
  end

  def hosts
    if enabled?
      proxy_config.fetch("hosts", [])
    else
      []
    end
  end

  def image
    proxy_config.fetch("image", DEFAULT_IMAGE)
  end

  def container_name
    "kamal-proxy"
  end

  def publish_args
    argumentize "--publish", [ "#{DEFAULT_HTTP_PORT}:#{DEFAULT_HTTP_PORT}", "#{DEFAULT_HTTPS_PORT}:#{DEFAULT_HTTPS_PORT}" ]
  end

  def deploy_options
    {
      host: proxy_config["host"],
      "deploy-timeout": proxy_config["deploy_timeout"],
      "drain-timeout": proxy_config["drain_timeout"],
      "health-check-interval": proxy_config.dig("health_check", "interval"),
      "health-check-timeout": proxy_config.dig("health_check", "timeout"),
      "health-check-path": proxy_config.dig("health_check", "path"),
      "target-timeout": proxy_config["response_timeout"]
    }.compact
  end

  def deploy_command_args
    optionize deploy_options
  end

  private
    attr_accessor :proxy_config
end
