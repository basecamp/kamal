class Kamal::Configuration::Accessory
  include Kamal::Configuration::Validation

  DEFAULT_NETWORK = "kamal"

  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :name, :accessory_config, :env, :proxy

  def initialize(name, config:)
    @name, @config, @accessory_config = name.inquiry, config, config.raw_config["accessories"][name]

    validate! \
      accessory_config,
      example: validation_yml["accessories"]["mysql"],
      context: "accessories/#{name}",
      with: Kamal::Configuration::Validator::Accessory

    @env = Kamal::Configuration::Env.new \
      config: accessory_config.fetch("env", {}),
      secrets: config.secrets,
      context: "accessories/#{name}/env"

    initialize_proxy if running_proxy?
  end

  def service_name
    accessory_config["service"] || "#{config.service}-#{name}"
  end

  def image
    accessory_config["image"]
  end

  def hosts
    hosts_from_host || hosts_from_hosts || hosts_from_roles
  end

  def port
    if port = accessory_config["port"]&.to_s
      port.include?(":") ? port : "#{port}:#{port}"
    end
  end

  def network_args
    argumentize "--network", network
  end

  def publish_args
    argumentize "--publish", port if port
  end

  def labels
    default_labels.merge(accessory_config["labels"] || {})
  end

  def label_args
    argumentize "--label", labels
  end

  def env_args
    [ *env.clear_args, *argumentize("--env-file", secrets_path) ]
  end

  def env_directory
    File.join(config.env_directory, "accessories")
  end

  def secrets_io
    env.secrets_io
  end

  def secrets_path
    File.join(config.env_directory, "accessories", "#{name}.env")
  end

  def files
    accessory_config["files"]&.to_h do |local_to_remote_mapping|
      local_file, remote_file = local_to_remote_mapping.split(":")
      [ expand_local_file(local_file), expand_remote_file(remote_file) ]
    end || {}
  end

  def directories
    accessory_config["directories"]&.to_h do |host_to_container_mapping|
      host_path, container_path = host_to_container_mapping.split(":")
      [ expand_host_path(host_path), container_path ]
    end || {}
  end

  def volumes
    specific_volumes + remote_files_as_volumes + remote_directories_as_volumes
  end

  def volume_args
    argumentize "--volume", volumes
  end

  def option_args
    if args = accessory_config["options"]
      optionize args
    else
      []
    end
  end

  def cmd
    accessory_config["cmd"]
  end

  def running_proxy?
    @accessory_config["proxy"].present?
  end

  def initialize_proxy
    @proxy = Kamal::Configuration::Proxy.new \
      config: config,
      proxy_config: accessory_config["proxy"],
      context: "accessories/#{name}/proxy"
  end

  private
    attr_accessor :config

    def default_labels
      { "service" => service_name }
    end

    def expand_local_file(local_file)
      if local_file.end_with?("erb")
        with_clear_env_loaded { read_dynamic_file(local_file) }
      else
        Pathname.new(File.expand_path(local_file)).to_s
      end
    end

    def with_clear_env_loaded
      env.clear.each { |k, v| ENV[k] = v }
      yield
    ensure
      env.clear.each { |k, v| ENV.delete(k) }
    end

    def read_dynamic_file(local_file)
      StringIO.new(ERB.new(File.read(local_file)).result)
    end

    def expand_remote_file(remote_file)
      service_name + remote_file
    end

    def specific_volumes
      accessory_config["volumes"] || []
    end

    def remote_files_as_volumes
      accessory_config["files"]&.collect do |local_to_remote_mapping|
        _, remote_file = local_to_remote_mapping.split(":")
        "#{service_data_directory + remote_file}:#{remote_file}"
      end || []
    end

    def remote_directories_as_volumes
      accessory_config["directories"]&.collect do |host_to_container_mapping|
        host_path, container_path = host_to_container_mapping.split(":")
        [ expand_host_path(host_path), container_path ].join(":")
      end || []
    end

    def expand_host_path(host_path)
      absolute_path?(host_path) ? host_path : File.join(service_data_directory, host_path)
    end

    def absolute_path?(path)
      Pathname.new(path).absolute?
    end

    def service_data_directory
      "$PWD/#{service_name}"
    end

    def hosts_from_host
      [ accessory_config["host"] ] if accessory_config.key?("host")
    end

    def hosts_from_hosts
      accessory_config["hosts"] if accessory_config.key?("hosts")
    end

    def hosts_from_roles
      if accessory_config.key?("roles")
        accessory_config["roles"].flat_map do |role|
          config.role(role)&.hosts || raise(Kamal::ConfigurationError, "Unknown role in accessories config: '#{role}'")
        end
      end
    end

    def network
      accessory_config["network"] || DEFAULT_NETWORK
    end
end
