class Kamal::Configuration::Role
  include Kamal::Configuration::Validation

  CORD_FILE = "cord"
  delegate :argumentize, :optionize, to: Kamal::Utils

  attr_reader :name, :config, :specialized_env, :specialized_logging, :specialized_healthcheck

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
      secrets_file: File.join(config.host_env_directory, "roles", "#{container_prefix}.env"),
      context: "servers/#{name}/env"

    @specialized_logging = Kamal::Configuration::Logging.new \
      logging_config: specializations.fetch("logging", {}),
      context: "servers/#{name}/logging"

    @specialized_healthcheck = Kamal::Configuration::Healthcheck.new \
      healthcheck_config: specializations.fetch("healthcheck", {}),
      context: "servers/#{name}/healthcheck"
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
    default_labels.merge(traefik_labels).merge(custom_labels)
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
    env(host).args
  end

  def asset_volume_args
    asset_volume&.docker_args
  end


  def health_check_args(cord: true)
    if running_traefik? || healthcheck.set_port_or_path?
      if cord && uses_cord?
        optionize({ "health-cmd" => health_check_cmd_with_cord, "health-interval" => healthcheck.interval })
          .concat(cord_volume.docker_args)
      else
        optionize({ "health-cmd" => healthcheck.cmd, "health-interval" => healthcheck.interval })
      end
    else
      []
    end
  end

  def healthcheck
    @healthcheck ||=
      if running_traefik?
        config.healthcheck.merge(specialized_healthcheck)
      else
        specialized_healthcheck
      end
  end

  def health_check_cmd_with_cord
    "(#{healthcheck.cmd}) && (stat #{cord_container_file} > /dev/null || exit 1)"
  end


  def running_traefik?
    if specializations["traefik"].nil?
      primary?
    else
      specializations["traefik"]
    end
  end

  def primary?
    self == @config.primary_role
  end


  def uses_cord?
    running_traefik? && cord_volume && healthcheck.cmd.present?
  end

  def cord_host_directory
    File.join config.run_directory_as_docker_volume, "cords", [ container_prefix, config.run_id ].join("-")
  end

  def cord_volume
    if (cord = healthcheck.cord)
      @cord_volume ||= Kamal::Configuration::Volume.new \
        host_path: File.join(config.run_directory, "cords", [ container_prefix, config.run_id ].join("-")),
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
      container_prefix
    end

    def custom_labels
      Hash.new.tap do |labels|
        labels.merge!(config.labels) if config.labels.present?
        labels.merge!(specializations["labels"]) if specializations["labels"].present?
      end
    end
end
