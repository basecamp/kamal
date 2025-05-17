class Kamal::Configuration::Proxy
  include Kamal::Configuration::Validation

  DEFAULT_LOG_REQUEST_HEADERS = [ "Cache-Control", "Last-Modified", "User-Agent" ]
  CONTAINER_NAME = "kamal-proxy"

  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :config, :proxy_config

  def initialize(config:, proxy_config:, context: "proxy")
    @config = config
    @proxy_config = proxy_config
    @proxy_config = {} if @proxy_config.nil?
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

  def deploy_options
    {
      host: hosts,
      tls: proxy_config["ssl"].presence,
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
      "tls-redirect": proxy_config.dig("ssl_redirect"),
      "log-request-header": proxy_config.dig("logging", "request_headers") || DEFAULT_LOG_REQUEST_HEADERS,
      "log-response-header": proxy_config.dig("logging", "response_headers"),
      "error-pages": error_pages
    }.compact
  end

  def deploy_command_args(target:)
    optionize ({ target: "#{target}:#{app_port}" }).merge(deploy_options), with: "="
  end

  def stop_options(drain_timeout: nil, message: nil)
    {
      "drain-timeout": seconds_duration(drain_timeout),
      message: message
    }.compact
  end

  def stop_command_args(**options)
    optionize stop_options(**options), with: "="
  end

  def merge(other)
    self.class.new config: config, proxy_config: proxy_config.deep_merge(other.proxy_config)
  end

  private
    def seconds_duration(value)
      value ? "#{value}s" : nil
    end

    def error_pages
      File.join config.proxy_boot.error_pages_container_directory, config.version if config.error_pages_path
    end
end
