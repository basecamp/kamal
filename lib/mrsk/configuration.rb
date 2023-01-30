require "active_support/ordered_options"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/module/delegation"
require "pathname"
require "erb"
require "mrsk/utils"

class Mrsk::Configuration
  delegate :service, :image, :servers, :env, :labels, :registry, :builder, to: :raw_config, allow_nil: true
  delegate :argumentize, :argumentize_env_with_secrets, to: Mrsk::Utils

  attr_accessor :raw_config

  class << self
    def create_from(base_config_file, destination: nil, version: "missing")
      new(load_config_file(base_config_file).tap do |config|
        if destination
          config.deep_merge! \
            load_config_file destination_config_file(base_config_file, destination)
        end
      end, version: version)
    end

    private
      def load_config_file(file)
        if file.exist?
          YAML.load(ERB.new(IO.read(file)).result).symbolize_keys
        else
          raise "Configuration file not found in #{file}"
        end
      end

      def destination_config_file(base_config_file, destination)
        dir, basename = base_config_file.split
        dir.join basename.to_s.remove(".yml") + ".#{destination}.yml"
      end
  end

  def initialize(raw_config, version: "missing", validate: true)
    @raw_config = ActiveSupport::InheritableOptions.new(raw_config)
    @version = version
    ensure_required_keys_present if validate
  end


  def roles
    @roles ||= role_names.collect { |role_name| Role.new(role_name, config: self) }
  end

  def role(name)
    roles.detect { |r| r.name == name.to_s }
  end

  def accessories
    @accessories ||= raw_config.accessories&.keys&.collect { |name| Mrsk::Configuration::Assessory.new(name, config: self) } || []
  end

  def accessory(name)
    accessories.detect { |a| a.name == name.to_s }
  end


  def all_hosts
    roles.flat_map(&:hosts)
  end

  def primary_web_host
    role(:web).hosts.first
  end

  def traefik_hosts
    roles.select(&:running_traefik?).flat_map(&:hosts)
  end


  def version
    @version
  end

  def repository
    [ raw_config.registry["server"], image ].compact.join("/")
  end

  def absolute_image
    "#{repository}:#{version}"
  end

  def service_with_version
    "#{service}-#{version}"
  end

  def keep_releases
    raw_config.keep_releases || 5
  end

  def env_args
    if raw_config.env.present?
      argumentize_env_with_secrets(raw_config.env)
    else
      []
    end
  end

  def volume_args
    if raw_config.volumes.present?
      argumentize "--volume", raw_config.volumes
    else
      []
    end
  end

  def ssh_user
    raw_config.ssh_user || "root"
  end

  def ssh_options
    { user: ssh_user, auth_methods: [ "publickey" ] }
  end

  def master_key
    unless raw_config.skip_master_key
      ENV["RAILS_MASTER_KEY"] || File.read(Pathname.new(File.expand_path("config/master.key")))
    end
  end

  def to_h
    {
      roles: role_names,
      hosts: all_hosts,
      primary_host: primary_web_host,
      version: version,
      repository: repository,
      absolute_image: absolute_image,
      service_with_version: service_with_version,
      env_args: env_args,
      volume_args: volume_args,
      ssh_options: ssh_options,
      builder: raw_config.builder,
      accessories: raw_config.accessories
    }.compact
  end


  private
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
    end

    def role_names
      raw_config.servers.is_a?(Array) ? [ "web" ] : raw_config.servers.keys.sort
    end
end

require "mrsk/configuration/role"
require "mrsk/configuration/accessory"
