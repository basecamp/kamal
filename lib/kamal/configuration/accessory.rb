require "ipaddr"

class Kamal::Configuration::Accessory
  include Kamal::Configuration::Validation

  DEFAULT_NETWORK = "kamal"

  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :name, :env, :proxy, :registry

  def initialize(name, config:)
    @name, @config, @accessory_config = name.inquiry, config, config.raw_config["accessories"][name]

    validate! \
      accessory_config,
      example: validation_yml["accessories"]["mysql"],
      context: "accessories/#{name}",
      with: Kamal::Configuration::Validator::Accessory

    ensure_valid_roles
    ensure_valid_port

    @env = initialize_env
    @proxy = initialize_proxy if running_proxy?
    @registry = initialize_registry if accessory_config["registry"].present?
  end

  def service_name
    accessory_config["service"] || "#{config.service}-#{name}"
  end

  def image
    [ registry&.server, accessory_config["image"] ].compact.join("/")
  end

  def hosts
    hosts_from_host || hosts_from_hosts || hosts_from_roles || hosts_from_tags
  end

  def port
    accessory_config["port"]&.to_s.presence
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
    accessory_config["files"]&.to_h do |config|
      parse_path_config(config, default_mode: "755") do |local, remote|
        {
          key: expand_local_file(local),
          host_path: expand_remote_file(remote),
          container_path: remote
        }
      end
    end || {}
  end

  def directories
    accessory_config["directories"]&.to_h do |config|
      parse_path_config(config, default_mode: nil) do |local, remote|
        {
          key: expand_host_path(local),
          host_path: expand_host_path_for_volume(local),
          container_path: remote
        }
      end
    end || {}
  end

  def volume_args
    argumentize("--volume", specific_volumes) + (path_volumes(files) + path_volumes(directories)).flat_map(&:docker_args)
  end

  def option_args
    optionize docker_options.reject { |key, _| key.to_s == "restart" }
  end

  def restart_policy
    restart_policy_option || "unless-stopped"
  end

  def cmd
    accessory_config["cmd"]
  end

  def running_proxy?
    accessory_config["proxy"].present?
  end

  private
    attr_reader :config, :accessory_config

    def initialize_env
      Kamal::Configuration::Env.new \
        config: accessory_config.fetch("env", {}),
        secrets: config.secrets,
        context: "accessories/#{name}/env"
    end

    def initialize_proxy
      Kamal::Configuration::Proxy.new \
        config: config,
        proxy_config: accessory_config["proxy"],
        role_name: "accessories/#{name}",
        context: "accessories/#{name}/proxy",
        secrets: config.secrets
    end

    def initialize_registry
      Kamal::Configuration::Registry.new \
        config: accessory_config,
        secrets: config.secrets,
        context: "accessories/#{name}/registry"
    end

    def default_labels
      { "service" => service_name }
    end

    def expand_local_file(local_file)
      if local_file.end_with?("erb")
        read_dynamic_file(local_file)
      else
        Pathname.new(File.expand_path(local_file)).to_s
      end
    end

    def read_dynamic_file(local_file)
      StringIO.new(render_dynamic_erb(File.read(local_file)))
    end

    # Render with a per-call ENV constant so parallel host threads cannot
    # clobber process-global ENV (SSHKit runs on(hosts) in :parallel).
    def render_dynamic_erb(template)
      renderer = Class.new
      renderer.const_set(:ENV, ENV.to_h.merge(env.to_h))
      renderer.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def render(template)
          ::ERB.new(template).result(binding)
        end
      RUBY
      renderer.new.render(template)
    end

    def expand_remote_file(remote_file)
      service_name + remote_file
    end

    def specific_volumes
      accessory_config["volumes"] || []
    end

    def docker_options
      accessory_config["options"] || {}
    end

    def restart_policy_option
      docker_options.find { |key, _| key.to_s == "restart" }&.last
    end

    def path_volumes(paths)
      paths.map do |local, config|
        Kamal::Configuration::Volume.new \
          host_path: config[:host_path],
          container_path: config[:container_path],
          options: config[:options]
      end
    end

    def parse_path_config(config, default_mode:)
      if config.is_a?(Hash)
        local, remote = config["local"], config["remote"]
        expanded = yield(local, remote)
        [
          expanded[:key],
          expanded.except(:key).merge(
            options: config["options"],
            mode: config["mode"] || default_mode,
            owner: config["owner"]
          )
        ]
      else
        local, remote, options = config.split(":", 3)
        expanded = yield(local, remote)
        [
          expanded[:key],
          expanded.except(:key).merge(
            options: options,
            mode: default_mode,
            owner: nil
          )
        ]
      end
    end

    def expand_host_path(host_path)
      absolute_path?(host_path) ? host_path : File.join(service_data_directory, host_path)
    end

    def expand_host_path_for_volume(host_path)
      absolute_path?(host_path) ? host_path : File.join(service_name, host_path)
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
      if accessory_config.key?("role")
       config.role(accessory_config["role"])&.hosts
      elsif accessory_config.key?("roles")
        accessory_config["roles"].flat_map { |role| config.role(role)&.hosts }
      end
    end

    def hosts_from_tags
      if accessory_config.key?("tag")
        extract_hosts_from_config_with_tag(accessory_config["tag"])
      elsif accessory_config.key?("tags")
        accessory_config["tags"].flat_map { |tag| extract_hosts_from_config_with_tag(tag) }
      end
    end

    def extract_hosts_from_config_with_tag(tag)
      if (servers_with_roles = config.raw_config.servers).is_a?(Hash)
        servers_with_roles.flat_map do |role, servers_in_role|
          servers_in_role.filter_map do |host|
            host.keys.first if host.is_a?(Hash) && host.values.first.include?(tag)
          end
        end
      end
    end

    def network
      accessory_config["network"] || DEFAULT_NETWORK
    end

    def ensure_valid_port
      ensure_bound_publish port, "port"

      # `options` passes flags straight to `docker run`, so publishing through it
      # has to clear the same bar as `port`.
      Array(docker_options["publish"]).each { |publish| ensure_bound_publish publish.to_s, "options/publish" }
    end

    def ensure_bound_publish(port_config, key)
      return if port_config.blank?

      host = port_config.split("/", 2).first

      bound =
        if host.start_with?("[")
          (ip = host[/\A\[([^\]]+)\]/, 1]) && valid_ip?(ip)
        elsif host.count(":") >= 2
          valid_ip?(host.split(":").first)
        end

      require_bind_host! port_config, key unless bound
    end

    def valid_ip?(str)
      IPAddr.new(str)
      true
    rescue IPAddr::InvalidAddressError, ArgumentError, TypeError
      false
    end

    def require_bind_host!(port_config, key)
      raise Kamal::ConfigurationError,
        "accessories/#{name}: #{key} \"#{port_config}\" must name a bind address — " \
        "\"127.0.0.1:PORT:PORT\" to keep it private, \"0.0.0.0:PORT:PORT\" to publish it. " \
        "Run `kamal accessory reboot #{name}` to rebind an existing container."
    end

    def ensure_valid_roles
      if accessory_config["roles"] && (missing_roles = accessory_config["roles"] - config.roles.map(&:name)).any?
        raise Kamal::ConfigurationError, "accessories/#{name}: unknown roles #{missing_roles.join(", ")}"
      elsif accessory_config["role"] && !config.role(accessory_config["role"])
        raise Kamal::ConfigurationError, "accessories/#{name}: unknown role #{accessory_config["role"]}"
      end
    end
end
