require "active_support/ordered_options"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/hash/keys"
require "erb"
require "net/ssh/proxy/jump"

class Kamal::Configuration
  delegate :service, :image, :labels, :hooks_path, to: :raw_config, allow_nil: true
  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :destination, :raw_config, :secrets
  attr_reader :accessories, :aliases, :boot, :builder, :env, :logging, :proxy, :servers, :ssh, :sshkit, :registry

  include Validation

  PROXY_MINIMUM_VERSION = "v0.8.7"
  PROXY_HTTP_PORT = 80
  PROXY_HTTPS_PORT = 443
  PROXY_LOG_MAX_SIZE = "10m"

  class << self
    def create_from(config_file:, destination: nil, version: nil)
      ENV["KAMAL_DESTINATION"] = destination

      raw_config = load_config_files(config_file, *destination_config_file(config_file, destination))

      new raw_config, destination: destination, version: version
    end

    private
      def load_config_files(*files)
        files.inject({}) { |config, file| config.deep_merge! load_config_file(file) }
      end

      def load_config_file(file)
        if file.exist?
          # Newer Psych doesn't load aliases by default
          load_method = YAML.respond_to?(:unsafe_load) ? :unsafe_load : :load
          YAML.send(load_method, ERB.new(File.read(file)).result).symbolize_keys
        else
          raise "Configuration file not found in #{file}"
        end
      end

      def destination_config_file(base_config_file, destination)
        base_config_file.sub_ext(".#{destination}.yml") if destination
      end
  end

  def initialize(raw_config, destination: nil, version: nil, validate: true)
    @raw_config = ActiveSupport::InheritableOptions.new(raw_config)
    @destination = destination
    @declared_version = version

    validate! raw_config, example: validation_yml.symbolize_keys, context: "", with: Kamal::Configuration::Validator::Configuration

    @secrets = Kamal::Secrets.new(destination: destination)

    # Eager load config to validate it, these are first as they have dependencies later on
    @servers = Servers.new(config: self)
    @registry = Registry.new(config: @raw_config, secrets: secrets)

    @accessories = @raw_config.accessories&.keys&.collect { |name| Accessory.new(name, config: self) } || []
    @aliases = @raw_config.aliases&.keys&.to_h { |name| [ name, Alias.new(name, config: self) ] } || {}
    @boot = Boot.new(config: self)
    @builder = Builder.new(config: self)
    @env = Env.new(config: @raw_config.env || {}, secrets: secrets)

    @logging = Logging.new(logging_config: @raw_config.logging)
    @proxy = Proxy.new(config: self, proxy_config: @raw_config.proxy || {})
    @ssh = Ssh.new(config: self, secrets: secrets)
    @sshkit = Sshkit.new(config: self)

    ensure_destination_if_required
    ensure_required_keys_present
    ensure_valid_kamal_version
    ensure_retain_containers_valid
    ensure_valid_service_name
    ensure_no_traefik_reboot_hooks
    ensure_one_host_for_ssl_roles
    ensure_unique_hosts_for_ssl_roles
  end

  def version=(version)
    @declared_version = version
  end

  def version
    @declared_version.presence || ENV["VERSION"] || git_version
  end

  def abbreviated_version
    if version
      # Don't abbreviate <sha>_uncommitted_<etc>
      if version.include?("_")
        version
      else
        version[0...7]
      end
    end
  end

  def minimum_version
    raw_config.minimum_version
  end

  def service_and_destination
    [ service, destination ].compact.join("-")
  end

  def roles
    servers.roles
  end

  def role(name)
    roles.detect { |r| r.name == name.to_s }
  end

  def accessory(name)
    accessories.detect { |a| a.name == name.to_s }
  end

  def all_hosts
    (roles + accessories).flat_map(&:hosts).uniq
  end

  def primary_host
    primary_role&.primary_host
  end

  def primary_role_name
    raw_config.primary_role || "web"
  end

  def primary_role
    role(primary_role_name)
  end

  def allow_empty_roles?
    raw_config.allow_empty_roles
  end

  def proxy_roles
    roles.select(&:running_proxy?)
  end

  def proxy_role_names
    proxy_roles.flat_map(&:name)
  end

  def proxy_hosts
    proxy_roles.flat_map(&:hosts).uniq
  end

  def repository
    [ registry.server, image ].compact.join("/")
  end

  def absolute_image
    "#{repository}:#{version}"
  end

  def latest_image
    "#{repository}:#{latest_tag}"
  end

  def latest_tag
    [ "latest", *destination ].join("-")
  end

  def service_with_version
    "#{service}-#{version}"
  end

  def require_destination?
    raw_config.require_destination
  end

  def retain_containers
    raw_config.retain_containers || 5
  end

  def volume_args
    if raw_config.volumes.present?
      argumentize "--volume", raw_config.volumes
    else
      []
    end
  end

  def logging_args
    logging.args
  end

  def readiness_delay
    raw_config.readiness_delay || 7
  end

  def deploy_timeout
    raw_config.deploy_timeout || 30
  end

  def drain_timeout
    raw_config.drain_timeout || 30
  end

  def run_directory
    ".kamal"
  end

  def apps_directory
    File.join run_directory, "apps"
  end

  def app_directory
    File.join apps_directory, service_and_destination
  end

  def env_directory
    File.join app_directory, "env"
  end

  def assets_directory
    File.join app_directory, "assets"
  end

  def hooks_path
    raw_config.hooks_path || ".kamal/hooks"
  end

  def asset_path
    raw_config.asset_path
  end

  def error_pages_path
    raw_config.error_pages_path
  end

  def env_tags
    @env_tags ||= if (tags = raw_config.env["tags"])
      tags.collect { |name, config| Env::Tag.new(name, config: config, secrets: secrets) }
    else
      []
    end
  end

  def env_tag(name)
    env_tags.detect { |t| t.name == name.to_s }
  end

  def proxy_publish_args(http_port, https_port, bind_ips = nil)
    ensure_valid_bind_ips(bind_ips)

    (bind_ips || [ nil ]).map do |bind_ip|
      bind_ip = format_bind_ip(bind_ip)
      publish_http = [ bind_ip, http_port, PROXY_HTTP_PORT ].compact.join(":")
      publish_https = [ bind_ip, https_port, PROXY_HTTPS_PORT ].compact.join(":")

      argumentize "--publish", [ publish_http, publish_https ]
    end.join(" ")
  end

  def proxy_logging_args(max_size)
    argumentize "--log-opt", "max-size=#{max_size}" if max_size.present?
  end

  def proxy_default_boot_options
    [
      *(KAMAL.config.proxy_publish_args(Kamal::Configuration::PROXY_HTTP_PORT, Kamal::Configuration::PROXY_HTTPS_PORT, nil)),
      *(KAMAL.config.proxy_logging_args(Kamal::Configuration::PROXY_LOG_MAX_SIZE))
    ]
  end

  def proxy_options_default
    [ *proxy_publish_args(PROXY_HTTP_PORT, PROXY_HTTPS_PORT), *proxy_logging_args(PROXY_LOG_MAX_SIZE) ]
  end

  def proxy_repository_name
    "basecamp"
  end

  def proxy_image_name
    "kamal-proxy"
  end

  def proxy_image_default
    "#{proxy_repository_name}/#{proxy_image_name}"
  end

  def proxy_container_name
    "kamal-proxy"
  end

  def proxy_directory
    File.join run_directory, "proxy"
  end

  def proxy_options_file
    File.join proxy_directory, "options"
  end

  def proxy_image_file
    File.join proxy_directory, "image"
  end

  def proxy_image_version_file
    File.join proxy_directory, "image_version"
  end

  def proxy_apps_directory
    File.join proxy_directory, "apps-config"
  end

  def proxy_apps_container_directory
    "/home/kamal-proxy/.apps-config"
  end

  def proxy_apps_volume
    Volume.new \
      host_path: proxy_apps_directory,
      container_path: proxy_apps_container_directory
  end

  def proxy_app_directory
    File.join proxy_apps_directory, service_and_destination
  end

  def proxy_app_container_directory
    File.join proxy_apps_container_directory, service_and_destination
  end

  def proxy_error_pages_directory
    File.join proxy_app_directory, "error_pages"
  end

  def proxy_error_pages_container_directory
    File.join proxy_app_container_directory, "error_pages"
  end

  def to_h
    {
      roles: role_names,
      hosts: all_hosts,
      primary_host: primary_host,
      version: version,
      repository: repository,
      absolute_image: absolute_image,
      service_with_version: service_with_version,
      volume_args: volume_args,
      ssh_options: ssh.to_h,
      sshkit: sshkit.to_h,
      builder: builder.to_h,
      accessories: raw_config.accessories,
      logging: logging_args
    }.compact
  end

  private
    # Will raise ArgumentError if any required config keys are missing
    def ensure_destination_if_required
      if require_destination? && destination.nil?
        raise ArgumentError, "You must specify a destination"
      end

      true
    end

    def ensure_required_keys_present
      %i[ service image registry servers ].each do |key|
        raise Kamal::ConfigurationError, "Missing required configuration for #{key}" unless raw_config[key].present?
      end

      unless role(primary_role_name).present?
        raise Kamal::ConfigurationError, "The primary_role #{primary_role_name} isn't defined"
      end

      if primary_role.hosts.empty?
        raise Kamal::ConfigurationError, "No servers specified for the #{primary_role.name} primary_role"
      end

      unless allow_empty_roles?
        roles.each do |role|
          if role.hosts.empty?
            raise Kamal::ConfigurationError, "No servers specified for the #{role.name} role. You can ignore this with allow_empty_roles: true"
          end
        end
      end

      true
    end

    def ensure_valid_service_name
      raise Kamal::ConfigurationError, "Service name can only include alphanumeric characters, hyphens, and underscores" unless raw_config[:service] =~ /^[a-z0-9_-]+$/i

      true
    end

    def ensure_valid_kamal_version
      if minimum_version && Gem::Version.new(minimum_version) > Gem::Version.new(Kamal::VERSION)
        raise Kamal::ConfigurationError, "Current version is #{Kamal::VERSION}, minimum required is #{minimum_version}"
      end

      true
    end

    def ensure_valid_bind_ips(bind_ips)
      bind_ips.present? && bind_ips.each do |ip|
        next if ip =~ Resolv::IPv4::Regex || ip =~ Resolv::IPv6::Regex
        raise ArgumentError, "Invalid publish IP address: #{ip}"
      end

      true
    end

    def ensure_retain_containers_valid
      raise Kamal::ConfigurationError, "Must retain at least 1 container" if retain_containers < 1

      true
    end

    def ensure_no_traefik_reboot_hooks
      hooks = %w[ pre-traefik-reboot post-traefik-reboot ].select { |hook_file| File.exist?(File.join(hooks_path, hook_file)) }

      if hooks.any?
        raise Kamal::ConfigurationError, "Found #{hooks.join(", ")}, these should be renamed to (pre|post)-proxy-reboot"
      end

      true
    end

    def ensure_one_host_for_ssl_roles
      roles.each(&:ensure_one_host_for_ssl)

      true
    end

    def ensure_unique_hosts_for_ssl_roles
      hosts = roles.select(&:ssl?).flat_map { |role| role.proxy.hosts }
      duplicates = hosts.tally.filter_map { |host, count| host if count > 1 }

      raise Kamal::ConfigurationError, "Different roles can't share the same host for SSL: #{duplicates.join(", ")}" if duplicates.any?

      true
    end

    def format_bind_ip(ip)
      # Ensure IPv6 address inside square brackets - e.g. [::1]
      if ip =~ Resolv::IPv6::Regex && ip !~ /\[.*\]/
        "[#{ip}]"
      else
        ip
      end
    end

    def role_names
      raw_config.servers.is_a?(Array) ? [ "web" ] : raw_config.servers.keys.sort
    end

    def git_version
      @git_version ||=
        if Kamal::Git.used?
          if Kamal::Git.uncommitted_changes.present? && !builder.git_clone?
            uncommitted_suffix = "_uncommitted_#{SecureRandom.hex(8)}"
          end
          [ Kamal::Git.revision, uncommitted_suffix ].compact.join
        else
          raise "Can't use commit hash as version, no git repository found in #{Dir.pwd}"
        end
    end
end
