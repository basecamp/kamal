require "active_support/ordered_options"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/module/delegation"
require "pathname"
require "erb"
require "mrsk/utils"

class Mrsk::Configuration
  delegate :service, :image, :servers, :env, :labels, :registry, :builder, to: :config, allow_nil: true

  class << self
    def create_from(base_config_file, destination: nil)
      new(load_config_file(base_config_file).tap do |config|
        if destination
          config.merge! \
            load_config_file destination_config_file(base_config_file, destination)
        end
      end)
    end

    def argumentize(argument, attributes, redacted: false)
      attributes.flat_map { |k, v| [ argument, redacted ? Mrsk::Utils.redact("#{k}=#{v}") : "#{k}=#{v}" ] }
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

  def initialize(config, validate: true)
    @config = ActiveSupport::InheritableOptions.new(config)
    ensure_required_keys_present if validate
  end


  def roles
    @roles ||= role_names.collect { |role_name| Role.new(role_name, config: self) }
  end

  def role(name)
    roles.detect { |r| r.name == name.to_s }
  end

  def hosts
    hosts =
      case
      when ENV["HOSTS"]
        ENV["HOSTS"].split(",")
      when ENV["ROLES"]
        role_names = ENV["ROLES"].split(",")
        roles.select { |r| role_names.include?(r.name) }.flat_map(&:hosts)
      else
        roles.flat_map(&:hosts)
      end

      if hosts.any?
        hosts
      else
        raise ArgumentError, "No hosts found"
      end
  end

  def primary_host
    role(:web).hosts.first
  end


  def version
    @version ||= ENV["VERSION"] || `git rev-parse HEAD`.strip
  end

  def repository
    [ config.registry["server"], image ].compact.join("/")
  end

  def absolute_image
    "#{repository}:#{version}"
  end

  def service_with_version
    "#{service}-#{version}"
  end


  def env_args
    if config.env.present?
      self.class.argumentize "-e", config.env
    else
      []
    end
  end

  def ssh_user
    config.ssh_user || "root"
  end

  def ssh_options
    { user: ssh_user, auth_methods: [ "publickey" ] }
  end

  def master_key
    ENV["RAILS_MASTER_KEY"] || File.read(Pathname.new(File.expand_path("config/master.key")))
  end

  def to_h
    {
      roles: role_names,
      hosts: hosts,
      primary_host: primary_host,
      version: version,
      repository: repository,
      absolute_image: absolute_image,
      service_with_version: service_with_version,
      env_args: env_args,
      ssh_options: ssh_options
    }
  end


  private
    attr_accessor :config

    def ensure_required_keys_present
      %i[ service image registry servers ].each do |key|
        raise ArgumentError, "Missing required configuration for #{key}" unless config[key].present?
      end

      if config.registry["username"].blank?
        raise ArgumentError, "You must specify a username for the registry in config/deploy.yml"
      end      

      if config.registry["password"].blank?
        raise ArgumentError, "You must specify a password for the registry in config/deploy.yml (or set the ENV variable if that's used)"
      end
    end

    def role_names
      config.servers.is_a?(Array) ? [ "web" ] : config.servers.keys.sort
    end
end

require "mrsk/configuration/role"
