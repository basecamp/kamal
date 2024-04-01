class Kamal::Commands::App < Kamal::Commands::Base
  include Assets, Containers, Cord, Execution, Images, Logging

  ACTIVE_DOCKER_STATUSES = [ :running, :restarting ]

  attr_reader :role, :role

  def initialize(config, role: nil)
    super(config)
    @role = role
  end

  def run(hostname: nil)
    docker :run,
      "--detach",
      "--restart unless-stopped",
      "--name", container_name,
      *([ "--hostname", hostname ] if hostname),
      "-e", "KAMAL_CONTAINER_NAME=\"#{container_name}\"",
      "-e", "KAMAL_VERSION=\"#{config.version}\"",
      *role.env_args,
      *role.health_check_args,
      *role.logging_args,
      *config.volume_args,
      *role.asset_volume_args,
      *role.label_args,
      *role.option_args,
      config.absolute_image,
      role.cmd
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
      xargs(config.stop_wait_time ? docker(:stop, "-t", config.stop_wait_time) : docker(:stop))
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
      %(while read line; do echo ${line##{role.container_prefix}-}; done) # Extract SHA from "service-role-dest-SHA"
  end


  def make_env_directory
    make_directory role.env.secrets_directory
  end

  def remove_env_file
    [ :rm, "-f", role.env.secrets_file ]
  end


  private
    def container_name(version = nil)
      [ role.container_prefix, version || config.version ].compact.join("-")
    end

    def filter_args(statuses: nil)
      argumentize "--filter", filters(statuses: statuses)
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
