class Kamal::Configuration::Proxy
  include Kamal::Configuration::Validation

  MINIMUM_VERSION = "v0.3.0"
  DEFAULT_HTTP_PORT = 80
  DEFAULT_HTTPS_PORT = 443
  DEFAULT_IMAGE = "basecamp/kamal-proxy:#{MINIMUM_VERSION}"
  DEFAULT_LOG_REQUEST_HEADERS = [ "Cache-Control", "Last-Modified", "User-Agent" ]

  delegate :argumentize, :optionize, to: Kamal::Utils

  def initialize(config:)
    @config = config
    @proxy_config = config.raw_config.proxy || {}
    validate! proxy_config, with: Kamal::Configuration::Validator::Proxy
  end

  def app_port
    proxy_config.fetch("app_port", 80)
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

  def ssl?
    proxy_config.fetch("ssl", false)
  end

  def deploy_options
    {
      host: proxy_config["host"],
      tls: proxy_config["ssl"],
      "deploy-timeout": seconds_duration(config.deploy_timeout),
      "drain-timeout": seconds_duration(config.drain_timeout),
      "health-check-interval": seconds_duration(proxy_config.dig("healthcheck", "interval")),
      "health-check-timeout": seconds_duration(proxy_config.dig("healthcheck", "timeout")),
      "health-check-path": proxy_config.dig("healthcheck", "path"),
      "target-timeout": seconds_duration(proxy_config["response_timeout"]),
      "buffer-requests": proxy_config.fetch("buffering", { "requests": true }).fetch("requests", true),
      "buffer-responses": proxy_config.fetch("buffering", { "responses": true }).fetch("responses", true),
      "buffer-memory": proxy_config.dig("buffering", "memory"),
      "max-request-body": proxy_config.dig("buffering", "max_request_body"),
      "max-response-body": proxy_config.dig("buffering", "max_response_body"),
      "forward-headers": proxy_config.dig("forward_headers"),
      "log-request-header": proxy_config.dig("logging", "request_headers") || DEFAULT_LOG_REQUEST_HEADERS,
      "log-response-header": proxy_config.dig("logging", "response_headers")
    }.compact
  end

  def deploy_command_args
    optionize deploy_options
  end

  def config_volume
    Kamal::Configuration::Volume.new \
      host_path: File.join(config.proxy_directory, "config"),
      container_path: "/home/kamal-proxy/.config/kamal-proxy"
  end

  private
    attr_reader :config, :proxy_config

    def seconds_duration(value)
      value ? "#{value}s" : nil
    end
end
