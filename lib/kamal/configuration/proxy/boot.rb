class Kamal::Configuration::Proxy::Boot
  MINIMUM_VERSION = "v0.9.0"
  DEFAULT_HTTP_PORT = 80
  DEFAULT_HTTPS_PORT = 443
  DEFAULT_LOG_MAX_SIZE = "10m"

  attr_reader :config
  delegate :argumentize, :optionize, to: Kamal::Utils

  def initialize(config:)
    @config = config
  end

  def publish_args(http_port, https_port, bind_ips = nil)
    ensure_valid_bind_ips(bind_ips)

    (bind_ips || [ nil ]).map do |bind_ip|
      bind_ip = format_bind_ip(bind_ip)
      publish_http = [ bind_ip, http_port, DEFAULT_HTTP_PORT ].compact.join(":")
      publish_https = [ bind_ip, https_port, DEFAULT_HTTPS_PORT ].compact.join(":")

      argumentize "--publish", [ publish_http, publish_https ]
    end.join(" ")
  end

  def logging_args(max_size)
    argumentize "--log-opt", "max-size=#{max_size}" if max_size.present?
  end

  def default_boot_options
    [
      *(publish_args(DEFAULT_HTTP_PORT, DEFAULT_HTTPS_PORT, nil)),
      *(logging_args(DEFAULT_LOG_MAX_SIZE))
    ]
  end

  def repository_name
    "basecamp"
  end

  def image_name
    "kamal-proxy"
  end

  def image_default
    "#{repository_name}/#{image_name}"
  end

  def container_name
    "kamal-proxy"
  end

  def host_directory
    File.join config.run_directory, "proxy"
  end

  def options_file
    File.join host_directory, "options"
  end

  def image_file
    File.join host_directory, "image"
  end

  def image_version_file
    File.join host_directory, "image_version"
  end

  def run_command_file
    File.join host_directory, "run_command"
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

  def app_directory
    File.join apps_directory, config.service_and_destination
  end

  def app_container_directory
    File.join apps_container_directory, config.service_and_destination
  end

  def error_pages_directory
    File.join app_directory, "error_pages"
  end

  def error_pages_container_directory
    File.join app_container_directory, "error_pages"
  end

  def tls_directory
    File.join app_directory, "tls"
  end

  def tls_container_directory
    File.join app_container_directory, "tls"
  end

  private
    def ensure_valid_bind_ips(bind_ips)
      bind_ips.present? && bind_ips.each do |ip|
        next if ip =~ Resolv::IPv4::Regex || ip =~ Resolv::IPv6::Regex
        raise ArgumentError, "Invalid publish IP address: #{ip}"
      end

      true
    end

    def format_bind_ip(ip)
      # Ensure IPv6 address inside square brackets - e.g. [::1]
      if ip =~ Resolv::IPv6::Regex && ip !~ /\A\[.*\]\z/
        "[#{ip}]"
      else
        ip
      end
    end
end
