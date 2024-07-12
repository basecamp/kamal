require "active_support/ordered_options"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/hash/keys"
require "pathname"
require "erb"
require "net/ssh/proxy/jump"

class Kamal::Configuration
  delegate :service, :image, :labels, :stop_wait_time, :hooks_path, to: :raw_config, allow_nil: true
  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :destination, :raw_config
  attr_reader :accessories, :boot, :builder, :env, :healthcheck, :logging, :traefik, :servers, :ssh, :sshkit, :registry

  include Validation

  class << self
    def create_from(config_file:, destination: nil, version: nil)
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
          YAML.send(load_method, ERB.new(IO.read(file)).result).symbolize_keys
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

    validate! raw_config, example: validation_yml.symbolize_keys, context: ""

    # Eager load config to validate it, these are first as they have dependencies later on
    @servers = Servers.new(config: self)
    @registry = Registry.new(config: self)

    @accessories = @raw_config.accessories&.keys&.collect { |name| Accessory.new(name, config: self) } || []
    @boot = Boot.new(config: self)
    @builder = Builder.new(config: self)
    @env = Env.new(config: @raw_config.env || {})

    @healthcheck = Healthcheck.new(healthcheck_config: @raw_config.healthcheck)
    @logging = Logging.new(logging_config: @raw_config.logging)
    @traefik = Traefik.new(config: self)
    @ssh = Ssh.new(config: self)
    @sshkit = Sshkit.new(config: self)

    ensure_destination_if_required
    ensure_required_keys_present
    ensure_valid_kamal_version
    ensure_retain_containers_valid
    ensure_valid_service_name
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

  def traefik_roles
    roles.select(&:running_traefik?)
  end

  def traefik_role_names
    traefik_roles.flat_map(&:name)
  end

  def traefik_hosts
    traefik_roles.flat_map(&:hosts).uniq
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


  def healthcheck_service
    [ "healthcheck", service, destination ].compact.join("-")
  end

  def readiness_delay
    raw_config.readiness_delay || 7
  end

  def run_id
    @run_id ||= SecureRandom.hex(16)
  end


  def run_directory
    raw_config.run_directory || ".kamal"
  end

  def run_directory_as_docker_volume
    if Pathname.new(run_directory).absolute?
      run_directory
    else
      File.join "$(pwd)", run_directory
    end
  end

  def hooks_path
    raw_config.hooks_path || ".kamal/hooks"
  end

  def asset_path
    raw_config.asset_path
  end


  def host_env_directory
    File.join(run_directory, "env")
  end

  def env_tags
    @env_tags ||= if (tags = raw_config.env["tags"])
      tags.collect { |name, config| Env::Tag.new(name, config: config) }
    else
      []
    end
  end

  def env_tag(name)
    env_tags.detect { |t| t.name == name.to_s }
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
      logging: logging_args,
      healthcheck: healthcheck.to_h
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

    def ensure_retain_containers_valid
      raise Kamal::ConfigurationError, "Must retain at least 1 container" if retain_containers < 1

      true
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
