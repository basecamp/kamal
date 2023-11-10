class Kamal::Configuration::Role
  CORD_FILE = "cord"
  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_accessor :name

  def initialize(name, config:)
   @name, @config = name.inquiry, config
  end

  def primary_host
    hosts.first
  end

  def hosts
    @hosts ||= extract_hosts_from_config
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
    default_labels.merge(traefik_labels).merge(custom_labels)
  end

  def label_args
    argumentize "--label", labels
  end


  def env
    if config.env && config.env["secret"]
      merged_env_with_secrets
    else
      merged_env
    end
  end

  def env_file
    Kamal::EnvFile.new(env)
  end

  def host_env_directory
    File.join config.host_env_directory, "roles"
  end

  def host_env_file_path
    File.join host_env_directory, "#{[config.service, name, config.destination].compact.join("-")}.env"
  end

  def env_args
    argumentize "--env-file", host_env_file_path
  end

  def asset_volume_args
    asset_volume&.docker_args
  end


  def health_check_args(cord: true)
    if health_check_cmd.present?
      if cord && uses_cord?
        optionize({ "health-cmd" => health_check_cmd_with_cord, "health-interval" => health_check_interval })
          .concat(cord_volume.docker_args)
      else
        optionize({ "health-cmd" => health_check_cmd, "health-interval" => health_check_interval })
      end
    else
      []
    end
  end

  def health_check_cmd
    health_check_options["cmd"] || http_health_check(port: health_check_options["port"], path: health_check_options["path"])
  end

  def health_check_cmd_with_cord
    "(#{health_check_cmd}) && (stat #{cord_container_file} > /dev/null || exit 1)"
  end

  def health_check_interval
    health_check_options["interval"] || "1s"
  end


  def running_traefik?
    name.web? || specializations["traefik"]
  end


  def uses_cord?
    running_traefik? && cord_volume && health_check_cmd.present?
  end

  def cord_host_directory
    File.join config.run_directory_as_docker_volume, "cords", [container_prefix, config.run_id].join("-")
  end

  def cord_volume
    if (cord = health_check_options["cord"])
      @cord_volume ||= Kamal::Configuration::Volume.new \
        host_path: File.join(config.run_directory, "cords", [container_prefix, config.run_id].join("-")),
        container_path: cord
    end
  end

  def cord_host_file
    File.join cord_volume.host_path, CORD_FILE
  end

  def cord_container_directory
    health_check_options.fetch("cord", nil)
  end

  def cord_container_file
    File.join cord_volume.container_path, CORD_FILE
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
    asset_path.present? && running_traefik?
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

  def stop_async?
    specializations["stop_asynchronously"] || false
  end

  private
    attr_accessor :config

    def extract_hosts_from_config
      if config.servers.is_a?(Array)
        config.servers
      else
        servers = config.servers[name]
        servers.is_a?(Array) ? servers : Array(servers["hosts"])
      end
    end

    def default_labels
      if config.destination
        { "service" => config.service, "role" => name, "destination" => config.destination }
      else
        { "service" => config.service, "role" => name }
      end
    end

    def traefik_labels
      if running_traefik?
        {
          # Setting a service property ensures that the generated service name will be consistent between versions
          "traefik.http.services.#{traefik_service}.loadbalancer.server.scheme" => "http",

          "traefik.http.routers.#{traefik_service}.rule" => "PathPrefix(`/`)",
          "traefik.http.routers.#{traefik_service}.priority" => "2",
          "traefik.http.middlewares.#{traefik_service}-retry.retry.attempts" => "5",
          "traefik.http.middlewares.#{traefik_service}-retry.retry.initialinterval" => "500ms",
          "traefik.http.routers.#{traefik_service}.middlewares" => "#{traefik_service}-retry@docker"
        }
      else
        {}
      end
    end

    def traefik_service
      [ config.service, name, config.destination ].compact.join("-")
    end

    def custom_labels
      Hash.new.tap do |labels|
        labels.merge!(config.labels) if config.labels.present?
        labels.merge!(specializations["labels"]) if specializations["labels"].present?
      end
    end

    def specializations
      if config.servers.is_a?(Array) || config.servers[name].is_a?(Array)
        { }
      else
        config.servers[name].except("hosts")
      end
    end

    def specialized_env
      specializations["env"] || {}
    end

    def merged_env
      config.env&.merge(specialized_env) || {}
    end

    # Secrets are stored in an array, which won't merge by default, so have to do it by hand.
    def merged_env_with_secrets
      merged_env.tap do |new_env|
        new_env["secret"] = Array(config.env["secret"]) + Array(specialized_env["secret"])

        # If there's no secret/clear split, everything is clear
        clear_app_env  = config.env["secret"] ? Array(config.env["clear"]) : Array(config.env["clear"] || config.env)
        clear_role_env = specialized_env["secret"] ? Array(specialized_env["clear"]) : Array(specialized_env["clear"] || specialized_env)

        new_env["clear"] = (clear_app_env + clear_role_env).uniq
      end
    end

    def http_health_check(port:, path:)
      "curl -f #{URI.join("http://localhost:#{port}", path)} || exit 1" if path.present? || port.present?
    end

    def health_check_options
      @health_check_options ||= begin
        options = specializations["healthcheck"] || {}
        options = config.healthcheck.merge(options) if running_traefik?
        options
      end
    end
end
