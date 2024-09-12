class Kamal::Configuration::Role
  include Kamal::Configuration::Validation

  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :name, :config, :specialized_env, :specialized_logging

  alias to_s name

  def initialize(name, config:)
    @name, @config = name.inquiry, config
    validate! \
      specializations,
      example: validation_yml["servers"]["workers"],
      context: "servers/#{name}",
      with: Kamal::Configuration::Validator::Role

    @specialized_env = Kamal::Configuration::Env.new \
      config: specializations.fetch("env", {}),
      secrets: config.secrets,
      context: "servers/#{name}/env"

    @specialized_logging = Kamal::Configuration::Logging.new \
      logging_config: specializations.fetch("logging", {}),
      context: "servers/#{name}/logging"
  end

  def primary_host
    hosts.first
  end

  def hosts
    tagged_hosts.keys
  end

  def env_tags(host)
    tagged_hosts.fetch(host).collect { |tag| config.env_tag(tag) }
  end

  def cmd
    specializations["cmd"]
  end

  def option_args
    if args = specializations["options"]
      optionize args
    else
      []
    end
  end

  def labels
    default_labels.merge(custom_labels)
  end

  def label_args
    argumentize "--label", labels
  end

  def logging_args
    logging.args
  end

  def logging
    @logging ||= config.logging.merge(specialized_logging)
  end


  def env(host)
    @envs ||= {}
    @envs[host] ||= [ config.env, specialized_env, *env_tags(host).map(&:env) ].reduce(:merge)
  end

  def env_args(host)
    [ *env(host).clear_args, *argumentize("--env-file", secrets_path) ]
  end

  def env_directory
    File.join(config.env_directory, "roles")
  end

  def secrets_io(host)
    env(host).secrets_io
  end

  def secrets_path
    File.join(config.env_directory, "roles", "#{container_prefix}.env")
  end

  def asset_volume_args
    asset_volume&.docker_args
  end


  def running_proxy?
    if specializations["proxy"].nil?
      primary?
    else
      specializations["proxy"]
    end
  end

  def primary?
    self == @config.primary_role
  end


  def container_name(version = nil)
    [ container_prefix, version || config.version ].compact.join("-")
  end

  def container_prefix
    [ config.service, name, config.destination ].compact.join("-")
  end


  def asset_path
    specializations["asset_path"] || config.asset_path
  end

  def assets?
    asset_path.present? && running_proxy?
  end

  def asset_volume(version = nil)
    if assets?
      Kamal::Configuration::Volume.new \
        host_path: asset_volume_path(version), container_path: asset_path
    end
  end

  def asset_extracted_path(version = nil)
    File.join config.run_directory, "assets", "extracted", container_name(version)
  end

  def asset_volume_path(version = nil)
    File.join config.run_directory, "assets", "volumes", container_name(version)
  end

  private
    def tagged_hosts
      {}.tap do |tagged_hosts|
        extract_hosts_from_config.map do |host_config|
          if host_config.is_a?(Hash)
            host, tags = host_config.first
            tagged_hosts[host] = Array(tags)
          elsif host_config.is_a?(String)
            tagged_hosts[host_config] = []
          end
        end
      end
    end

    def extract_hosts_from_config
      if config.raw_config.servers.is_a?(Array)
        config.raw_config.servers
      else
        servers = config.raw_config.servers[name]
        servers.is_a?(Array) ? servers : Array(servers["hosts"])
      end
    end

    def default_labels
      { "service" => config.service, "role" => name, "destination" => config.destination }
    end

    def specializations
      if config.raw_config.servers.is_a?(Array) || config.raw_config.servers[name].is_a?(Array)
        {}
      else
        config.raw_config.servers[name]
      end
    end

    def custom_labels
      Hash.new.tap do |labels|
        labels.merge!(config.labels) if config.labels.present?
        labels.merge!(specializations["labels"]) if specializations["labels"].present?
      end
    end
end
