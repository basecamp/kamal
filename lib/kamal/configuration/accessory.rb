class Kamal::Configuration::Accessory
  delegate :argumentize, :optionize, to: Kamal::Utils
  delegate :volume_args, :directories, :files, to: :volumes_config
  attr_accessor :name, :specifics, :volumes_config

  def initialize(name, config:)
    @name, @config, @specifics = name.inquiry, config, config.raw_config["accessories"][name]
    @volumes_config = Kamal::Configuration::VolumesFilesAndFolders.new service_name, @specifics
  end

  def service_name
    "#{config.service}-#{name}"
  end

  def image
    specifics["image"]
  end

  def hosts
    if (specifics.keys & ["host", "hosts", "roles"]).size != 1
      raise ArgumentError, "Specify one of `host`, `hosts` or `roles` for accessory `#{name}`"
    end

    hosts_from_host || hosts_from_hosts || hosts_from_roles
  end

  def port
    if port = specifics["port"]&.to_s
      port.include?(":") ? port : "#{port}:#{port}"
    end
  end

  def publish_args
    argumentize "--publish", port if port
  end

  def labels
    default_labels.merge(specifics["labels"] || {})
  end

  def label_args
    argumentize "--label", labels
  end

  def env
    specifics["env"] || {}
  end

  def env_file
    Kamal::EnvFile.new(env)
  end

  def host_env_directory
    File.join config.host_env_directory, "accessories"
  end

  def host_env_file_path
    File.join host_env_directory, "#{service_name}.env"
  end

  def env_args
    argumentize "--env-file", host_env_file_path
  end

  def option_args
    if args = specifics["options"]
      optionize args
    else
      []
    end
  end

  def cmd
    specifics["cmd"]
  end

  private
    attr_accessor :config

    def default_labels
      { "service" => service_name }
    end

    def hosts_from_host
      if specifics.key?("host")
        host = specifics["host"]
        if host
          [host]
        else
          raise ArgumentError, "Missing host for accessory `#{name}`"
        end
      end
    end

    def hosts_from_hosts
      if specifics.key?("hosts")
        hosts = specifics["hosts"]
        if hosts.is_a?(Array)
          hosts
        else
          raise ArgumentError, "Hosts should be an Array for accessory `#{name}`"
        end
      end
    end

    def hosts_from_roles
      if specifics.key?("roles")
        specifics["roles"].flat_map { |role| config.role(role).hosts }
      end
    end
end
