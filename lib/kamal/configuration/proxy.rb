class Kamal::Configuration::Proxy
  include Kamal::Configuration::Validation

  DEFAULT_LOG_REQUEST_HEADERS = [ "Cache-Control", "Last-Modified", "User-Agent" ]
  CONTAINER_NAME = "kamal-proxy"

  MINIMUM_VERSION = "v0.7.0"
  HTTP_PORT = 80
  HTTPS_PORT = 443

  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :config, :proxy_config

  def initialize(config:, proxy_config:, context: "proxy")
    @config = config
    @proxy_config = proxy_config
    validate! @proxy_config, with: Kamal::Configuration::Validator::Proxy, context: context
  end

  def app_port
    proxy_config.fetch("app_port", 80)
  end

  def ssl?
    proxy_config.fetch("ssl", false)
  end

  def hosts
    proxy_config["hosts"] || proxy_config["host"]&.split(",") || []
  end

  def publish_args(http_port, https_port)
    argumentize "--publish", [ "#{http_port}:#{HTTP_PORT}", "#{https_port}:#{HTTPS_PORT}" ]
  end

  def default_options
    publish_args HTTP_PORT, HTTPS_PORT
  end

  def image
    "basecamp/kamal-proxy:#{MINIMUM_VERSION}"
  end

  def container_name
    "kamal-proxy"
  end

  def directory
    File.join config.run_directory, "proxy"
  end

  def options_file
    File.join directory, "options"
  end

  def deploy_options
    {
      host: hosts,
      tls: proxy_config["ssl"] ? true : nil,
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

  def deploy_command_args(target:)
    optionize ({ target: "#{target}:#{app_port}" }).merge(deploy_options)
  end

  def merge(other)
    self.class.new config: config, proxy_config: proxy_config.deep_merge(other.proxy_config)
  end

  private
    def seconds_duration(value)
      value ? "#{value}s" : nil
    end
end
