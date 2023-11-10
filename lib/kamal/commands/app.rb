class Kamal::Commands::App < Kamal::Commands::Base
  include Assets, Containers, Cord, Execution, Images, Logging

  ACTIVE_DOCKER_STATUSES = [ :running, :restarting ]

  attr_reader :role, :role_config

  def initialize(config, role: nil)
    super(config)
    @role = role
    @role_config = config.role(self.role)
  end

  def run(hostname: nil)
    docker :run,
      "--detach",
      "--restart unless-stopped",
      "--name", container_name,
      *(["--hostname", hostname] if hostname),
      "-e", "KAMAL_CONTAINER_NAME=\"#{container_name}\"",
      "-e", "KAMAL_VERSION=\"#{config.version}\"",
      *role_config.env_args,
      *role_config.health_check_args,
      *config.logging_args,
      *config.volume_args,
      *role_config.asset_volume_args,
      *role_config.label_args,
      *role_config.option_args,
      config.absolute_image,
      role_config.cmd
  end

  def start
    docker :start, container_name
  end

  def status(version:)
    pipe container_id_for_version(version), xargs(docker(:inspect, "--format", DOCKER_HEALTH_STATUS_FORMAT))
  end

  def stop(version: nil)
    pipe \
      version ? container_id_for_version(version) : current_running_container_id,
      xargs(docker_stop)
  end

  def stop_containers_async(ids)
    [:nohup, :sh, "-c", "'" + stop_containers(ids).join(" ")+ "'", ">", "/dev/null", "2>&1", "&", :disown]
  end

  def stop_containers(ids)
    pipe \
      [:echo, "\"#{ids.join("\n")}\""],
      xargs(docker_stop)
  end

  def stop_container(id)
    [*docker_stop, id]
  end

  def docker_stop
    config.stop_wait_time ? docker(:stop, "-t", config.stop_wait_time) : docker(:stop)
  end

  def info
    docker :ps, *filter_args
  end


  def current_running_container_id
    docker :ps, "--quiet", *filter_args(statuses: ACTIVE_DOCKER_STATUSES), "--latest"
  end
  
  def container_id_for_version(version, only_running: false)
    container_id_for(container_name: container_name(version), only_running: only_running)
  end

  def current_running_version
    list_versions("--latest", statuses: ACTIVE_DOCKER_STATUSES)
  end

  def list_versions(*docker_args, statuses: nil)
    pipe \
      docker(:ps, *filter_args(statuses: statuses), *docker_args, "--format", '"{{.Names}}"'),
      %(while read line; do echo ${line##{role_config.container_prefix}-}; done) # Extract SHA from "service-role-dest-SHA"
  end


  def make_env_directory
    make_directory role_config.host_env_directory
  end

  def remove_env_file
    [ :rm, "-f", role_config.host_env_file_path ]
  end


  private
    def container_name(version = nil)
      [ role_config.container_prefix, version || config.version ].compact.join("-")
    end

    def filter_args(statuses: nil)
      argumentize "--filter", filters(statuses: statuses)
    end

    def service_role_dest
      [ config.service, role, config.destination ].compact.join("-")
    end

    def filters(statuses: nil)
      [ "label=service=#{config.service}" ].tap do |filters|
        filters << "label=destination=#{config.destination}" if config.destination
        filters << "label=role=#{role}" if role
        statuses&.each do |status|
          filters << "status=#{status}"
        end
      end
    end
end
