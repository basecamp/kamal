class Kamal::Commands::App < Kamal::Commands::Base
  include Assets, Containers, Cord, Execution, Images, Logging

  ACTIVE_DOCKER_STATUSES = [ :running, :restarting ]

  attr_reader :role, :host

  def initialize(config, role: nil, host: nil)
    super(config)
    @role = role
    @host = host
  end

  def run(hostname: nil)
    docker :run,
      "--detach",
      "--restart unless-stopped",
      "--name", container_name,
      *([ "--hostname", hostname ] if hostname),
      "-e", "KAMAL_CONTAINER_NAME=\"#{container_name}\"",
      "-e", "KAMAL_VERSION=\"#{config.version}\"",
      *role.env_args(host),
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
    current_running_container(format: "--quiet")
  end

  def container_id_for_version(version, only_running: false)
    container_id_for(container_name: container_name(version), only_running: only_running)
  end

  def current_running_version
    pipe \
      current_running_container(format: "--format '{{.Names}}'"),
      extract_version_from_name
  end

  def list_versions(*docker_args, statuses: nil)
    pipe \
      docker(:ps, *filter_args(statuses: statuses), *docker_args, "--format", '"{{.Names}}"'),
      extract_version_from_name
  end


  def make_env_directory
    make_directory role.env(host).secrets_directory
  end

  def remove_env_file
    [ :rm, "-f", role.env(host).secrets_file ]
  end


  private
    def container_name(version = nil)
      [ role.container_prefix, version || config.version ].compact.join("-")
    end

    def latest_image_id
      docker :image, :ls, *argumentize("--filter", "reference=#{config.latest_image}"), "--format", "'{{.ID}}'"
    end

    def current_running_container(format:)
      pipe \
        shell(chain(latest_image_container(format: format), latest_container(format: format))),
        [ :head, "-1" ]
    end

    def latest_image_container(format:)
      latest_container format: format, filters: [ "ancestor=$(#{latest_image_id.join(" ")})" ]
    end

    def latest_container(format:, filters: nil)
      docker :ps, "--latest", *format, *filter_args(statuses: ACTIVE_DOCKER_STATUSES), argumentize("--filter", filters)
    end

    def filter_args(statuses: nil)
      argumentize "--filter", filters(statuses: statuses)
    end

    def extract_version_from_name
      # Extract SHA from "service-role-dest-SHA"
      %(while read line; do echo ${line##{role.container_prefix}-}; done)
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
