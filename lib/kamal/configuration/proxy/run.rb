class Kamal::Configuration::Proxy::Run
  MINIMUM_VERSION = "v0.9.0"
  DEFAULT_HTTP_PORT = 80
  DEFAULT_HTTPS_PORT = 443
  DEFAULT_LOG_MAX_SIZE = "10m"

  attr_reader :config, :run_config
  delegate :argumentize, :optionize, to: Kamal::Utils

  def initialize(config, run_config:, context: "proxy/run")
    @config = config
    @run_config = run_config
    @context = context
  end

  def debug?
    run_config.fetch("debug", nil)
  end

  def publish?
    run_config.fetch("publish", true)
  end

  def http_port
    run_config.fetch("http_port", DEFAULT_HTTP_PORT)
  end

  def https_port
    run_config.fetch("https_port", DEFAULT_HTTPS_PORT)
  end

  def bind_ips
    run_config.fetch("bind_ips", nil)
  end

  def publish_args
    if publish?
      (bind_ips || [ nil ]).map do |bind_ip|
        bind_ip = format_bind_ip(bind_ip)
        publish_http = [ bind_ip, http_port, DEFAULT_HTTP_PORT ].compact.join(":")
        publish_https = [ bind_ip, https_port, DEFAULT_HTTPS_PORT ].compact.join(":")

        argumentize "--publish", [ publish_http, publish_https ]
      end.join(" ")
    end
  end

  def log_max_size
    run_config.fetch("log_max_size", DEFAULT_LOG_MAX_SIZE)
  end

  def logging_args
    argumentize "--log-opt", "max-size=#{log_max_size}" if log_max_size.present?
  end

  def version
    run_config.fetch("version", MINIMUM_VERSION)
  end

  def registry
    run_config.fetch("registry", nil)
  end

  def repository
    run_config.fetch("repository", "basecamp/kamal-proxy")
  end

  def image
    "#{[ registry, repository ].compact.join("/")}:#{version}"
  end

  def container_name
    "kamal-proxy"
  end

  def options_args
    if args = run_config["options"]
      optionize args
    end
  end

  def run_command
    [ "kamal-proxy", "run", *optionize(run_command_options) ].join(" ")
  end

  def metrics_port
    run_config["metrics_port"]
  end

  def run_command_options
    { debug: debug? || nil, "metrics-port": metrics_port }.compact
  end

  def docker_options_args
    [
      *apps_volume_args,
      *publish_args,
      *logging_args,
      *("--expose=#{metrics_port}" if metrics_port.present?),
      *options_args
    ].compact
  end

  def host_directory
    File.join config.run_directory, "proxy"
  end

  def apps_directory
    File.join host_directory, "apps-config"
  end

  def apps_container_directory
    "/home/kamal-proxy/.apps-config"
  end

  def apps_volume
    Kamal::Configuration::Volume.new \
      host_path: apps_directory,
      container_path: apps_container_directory
  end

  def apps_volume_args
    [ apps_volume.docker_args ]
  end

  def app_directory
    File.join apps_directory, config.service_and_destination
  end

  def app_container_directory
    File.join apps_container_directory, config.service_and_destination
  end

  private
    def format_bind_ip(ip)
      # Ensure IPv6 address inside square brackets - e.g. [::1]
      if ip =~ Resolv::IPv6::Regex && ip !~ /\A\[.*\]\z/
        "[#{ip}]"
      else
        ip
      end
    end
end
