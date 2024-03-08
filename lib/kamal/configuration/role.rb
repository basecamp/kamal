class Kamal::Configuration::Role
  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_accessor :name
  alias to_s name

  def initialize(name, config:)
    @name, @config = name.inquiry, config
    @tagged_hosts ||= extract_tagged_hosts_from_config
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
    args = config.logging || {}
    args.deep_merge!(specializations["logging"]) if specializations["logging"].present?

    if args.any?
      optionize({ "log-driver" => args["driver"] }.compact) +
        argumentize("--log-opt", args["options"])
    else
      config.logging_args
    end
  end


  def env(host)
    @envs ||= {}
    @envs[host] ||= [ base_env, specialized_env, *env_tags(host).map(&:env) ].reduce(:merge)
  end

  def env_args(host)
    env(host).args
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
    attr_accessor :config, :tagged_hosts

    def extract_tagged_hosts_from_config
      {}.tap do |tagged_hosts|
        extract_hosts_from_config.map do |host_config|
          if host_config.is_a?(Hash)
            raise ArgumentError, "Multiple hosts found: #{host_config.inspect}" unless host_config.size == 1

            host, tags = host_config.first
            tagged_hosts[host] = Array(tags)
          elsif host_config.is_a?(String) || host_config.is_a?(Symbol)
            tagged_hosts[host_config] = []
          else
            raise ArgumentError, "Invalid host config: #{host_config.inspect}"
          end
        end
      end
    end

    def extract_hosts_from_config
      if config.servers.is_a?(Array)
        config.servers
      else
        servers = config.servers[name]
        servers.is_a?(Array) ? servers : Array(servers["hosts"])
      end
    end

    def default_labels
      { "service" => config.service, "role" => name, "destination" => config.destination }
    end

    def custom_labels
      Hash.new.tap do |labels|
        labels.merge!(config.labels) if config.labels.present?
        labels.merge!(specializations["labels"]) if specializations["labels"].present?
      end
    end

    def specializations
      if config.servers.is_a?(Array) || config.servers[name].is_a?(Array)
        {}
      else
        config.servers[name].except("hosts")
      end
    end

    def specialized_env
      Kamal::Configuration::Env.from_config config: specializations.fetch("env", {})
    end

    # Secrets are stored in an array, which won't merge by default, so have to do it by hand.
    def base_env
      Kamal::Configuration::Env.from_config \
        config: config.env,
        secrets_file: File.join(config.host_env_directory, "roles", "#{container_prefix}.env")
    end
end
