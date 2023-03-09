require "active_support/ordered_options"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/module/delegation"
require "pathname"
require "erb"
require "net/ssh/proxy/jump"
require "json-schema"

class Mrsk::Configuration
  delegate :service, :image, :servers, :env, :labels, :registry, :builder, to: :raw_config, allow_nil: true
  delegate :argumentize, :argumentize_env_with_secrets, to: Mrsk::Utils

  attr_accessor :version
  attr_accessor :destination
  attr_accessor :raw_config

  class << self
    def create_from(base_config_file, destination: nil, version: "missing")
      new(load_config_file(base_config_file).tap do |config|
        if destination
          config.deep_merge! \
            load_config_file destination_config_file(base_config_file, destination)
        end
      end, destination: destination, version: version)
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

  def initialize(raw_config, destination: nil, version: "missing", validate: true)
    validate!(raw_config) if validate
    @raw_config = ActiveSupport::InheritableOptions.new(raw_config)
    @destination = destination
    @version = version
    ensure_env_available
  end


  def roles
    @roles ||= role_names.collect { |role_name| Role.new(role_name, config: self) }
  end

  def role(name)
    roles.detect { |r| r.name == name.to_s }
  end

  def accessories
    @accessories ||= raw_config.accessories&.keys&.collect { |name| Mrsk::Configuration::Accessory.new(name, config: self) } || []
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
    if raw_config.ssh.present?
      raw_config.ssh["user"] || "root"
    else
      "root"
    end
  end

  def ssh_proxy
    if raw_config.ssh.present? && raw_config.ssh["proxy"]
      Net::SSH::Proxy::Jump.new \
        raw_config.ssh["proxy"].include?("@") ? raw_config.ssh["proxy"] : "root@#{raw_config.ssh["proxy"]}"
    end
  end

  def ssh_options
    { user: ssh_user, proxy: ssh_proxy, auth_methods: [ "publickey" ] }.compact
  end

  def audit_broadcast_cmd
    raw_config.audit_broadcast_cmd
  end

  def healthcheck
    { "path" => "/up", "port" => 3000 }.merge(raw_config.healthcheck || {})
  end

  def readiness_delay
    raw_config.readiness_delay || 7
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
      accessories: raw_config.accessories,
      healthcheck: healthcheck
    }.compact
  end

  def validate!(config)
    schema_file_path = File.join(File.dirname(File.expand_path(__FILE__)), "configuration/schema.yaml")
    schema = YAML.load(IO.read(schema_file_path))
    JSON::Validator.validate!(schema, config)
  rescue JSON::Schema::ValidationError => e
    raise Mrsk::Configuration::Error, e.message # Temporary to pass tests
  end

  private

    # Will raise KeyError if any secret ENVs are missing
    def ensure_env_available
      env_args
      roles.each(&:env_args)

      true
    end

    def role_names
      raw_config.servers.is_a?(Array) ? [ "web" ] : raw_config.servers.keys.sort
    end
end
