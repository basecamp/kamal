require "active_support/ordered_options"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/module/delegation"
require "pathname"
require "erb"
require "net/ssh/proxy/jump"

class Kamal::Configuration
  delegate :service, :image, :servers, :env, :labels, :registry, :stop_wait_time, :hooks_path, to: :raw_config, allow_nil: true
  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :destination, :raw_config

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
          YAML.load(ERB.new(IO.read(file)).result).symbolize_keys
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
    valid? if validate
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
    @roles ||= role_names.collect { |role_name| Role.new(role_name, config: self) }
  end

  def role(name)
    roles.detect { |r| r.name == name.to_s }
  end

  def accessories
    @accessories ||= raw_config.accessories&.keys&.collect { |name| Kamal::Configuration::Accessory.new(name, config: self) } || []
  end

  def accessory(name)
    accessories.detect { |a| a.name == name.to_s }
  end


  def all_hosts
    roles.flat_map(&:hosts).uniq
  end

  def primary_host
    primary_role.primary_host
  end

  def primary_role
    role(:web) || roles.first
  end

  def traefik_hosts
    roles.select(&:running_traefik?).flat_map(&:hosts).uniq
  end


  def repository
    [ raw_config.registry["server"], image ].compact.join("/")
  end

  def absolute_image
    "#{repository}:#{version}"
  end

  def latest_image
    "#{repository}:latest"
  end

  def service_with_version
    "#{service}-#{version}"
  end

  def require_destination?
    raw_config.require_destination
  end


  def volume_args
    if raw_config.volumes.present?
      argumentize "--volume", raw_config.volumes
    else
      []
    end
  end

  def logging_args
    if raw_config.logging.present?
      optionize({ "log-driver" => raw_config.logging["driver"] }.compact) +
        argumentize("--log-opt", raw_config.logging["options"])
    else
      argumentize("--log-opt", { "max-size" => "10m" })
    end
  end


  def boot
    Kamal::Configuration::Boot.new(config: self)
  end

  def builder
    Kamal::Configuration::Builder.new(config: self)
  end

  def traefik
    raw_config.traefik || {}
  end

  def ssh
    Kamal::Configuration::Ssh.new(config: self)
  end

  def sshkit
    Kamal::Configuration::Sshkit.new(config: self)
  end


  def healthcheck
    { "path" => "/up", "port" => 3000, "max_attempts" => 7, "exposed_port" => 3999, "cord" => "/tmp/kamal-cord", "log_lines" => 50 }.merge(raw_config.healthcheck || {})
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

  def host_env_directory
    "#{run_directory}/env"
  end

  def asset_path
    raw_config.asset_path
  end


  def valid?
    ensure_destination_if_required && ensure_required_keys_present && ensure_valid_kamal_version
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
      healthcheck: healthcheck
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
        raise ArgumentError, "Missing required configuration for #{key}" unless raw_config[key].present?
      end

      if raw_config.registry["username"].blank?
        raise ArgumentError, "You must specify a username for the registry in config/deploy.yml"
      end

      if raw_config.registry["password"].blank?
        raise ArgumentError, "You must specify a password for the registry in config/deploy.yml (or set the ENV variable if that's used)"
      end

      roles.each do |role|
        if role.hosts.empty?
          raise ArgumentError, "No servers specified for the #{role.name} role"
        end
      end

      true
    end

    def ensure_valid_kamal_version
      if minimum_version && Gem::Version.new(minimum_version) > Gem::Version.new(Kamal::VERSION)
        raise ArgumentError, "Current version is #{Kamal::VERSION}, minimum required is #{minimum_version}"
      end

      true
    end


    def role_names
      raw_config.servers.is_a?(Array) ? [ "web" ] : raw_config.servers.keys.sort
    end

    def git_version
      @git_version ||=
        if Kamal::Git.used?
          [ Kamal::Git.revision, Kamal::Git.uncommitted_changes.present? ? "_uncommitted_#{SecureRandom.hex(8)}" : "" ].join
        else
          raise "Can't use commit hash as version, no git repository found in #{Dir.pwd}"
        end
    end
end
