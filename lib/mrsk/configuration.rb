require "active_support/ordered_options"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/module/delegation"
require "pathname"
require "erb"

class Mrsk::Configuration
  delegate :service, :image, :servers, :env, :labels, :registry, :builder, to: :config, allow_nil: true

  class << self
    def load_file(file)
      if file.exist?
        new YAML.load(ERB.new(IO.read(file)).result).symbolize_keys
      else
        raise "Configuration file not found in #{file}"
      end
    end

    def argumentize(argument, attributes)
      attributes.flat_map { |k, v| [ argument, "#{k}=#{v}" ] }
    end
  end

  def initialize(config, validate: true)
    @config = ActiveSupport::InheritableOptions.new(config)
    validate_configuration if validate
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


  private
    attr_accessor :config

    def validate_configuration
      validator = Mrsk::Configuration::Validator.new config
      errors = validator.validate
      puts "\e[34m-----> MRSC has #{errors.size} #{'error'.pluralize(errors.size)} \e[0m" if errors.any?
      errors.each { |err| puts; raise ArgumentError, "\n\n #{err} \n\n" }
      abort unless errors.empty?
    end

    def role_names
      config.servers.is_a?(Array) ? [ "web" ] : config.servers.keys.sort
    end
end

require "mrsk/configuration/role"
require "mrsk/configuration/validator"