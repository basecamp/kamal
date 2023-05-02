class Mrsk::Commands::App < Mrsk::Commands::Base
  attr_reader :role

  def initialize(config, role: nil)
    super(config)
    @role = role
  end

  def run
    role = config.role(self.role)

    docker :run,
      "--detach",
      "--restart unless-stopped",
      "--name", container_name.shellescape,
      "-e", "MRSK_CONTAINER_NAME=#{container_name.shellescape}",
      *role.env_args,
      *role.health_check_args,
      *config.logging_args,
      *config.volume_args,
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


  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      current_running_container_id,
      "xargs docker logs#{" --since #{since}" if since}#{" --tail #{lines}" if lines} 2>&1",
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh \
      pipe(
        current_running_container_id,
        "xargs docker logs --timestamps --tail 10 --follow 2>&1",
        (%(grep "#{grep}") if grep)
      ),
      host: host
  end


  def execute_in_existing_container(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      container_name,
      *command
  end

  def execute_in_new_container(*command, interactive: false)
    docker :run,
      ("-it" if interactive),
      "--rm",
      *config.env_args,
      *config.volume_args,
      config.absolute_image,
      *command
  end

  def execute_in_existing_container_over_ssh(*command, host:)
    run_over_ssh execute_in_existing_container(*command, interactive: true), host: host
  end

  def execute_in_new_container_over_ssh(*command, host:)
    run_over_ssh execute_in_new_container(*command, interactive: true), host: host
  end


  def current_running_container_id
    docker :ps, "--quiet", *filter_args(status: :running), "--latest"
  end

  def container_id_for_version(version)
    container_id_for(container_name: container_name(version))
  end

  def current_running_version
    list_versions("--latest", status: :running)
  end

  def list_versions(*docker_args, status: nil)
    pipe \
      docker(:ps, *filter_args(status: status), *docker_args, "--format", '"{{.Names}}"'),
      %(grep -oE "\\-[^-]+$"), # Extract SHA from "service-role-dest-SHA"
      %(cut -c 2-)
  end

  def list_containers
    docker :container, :ls, "--all", *filter_args
  end

  def list_container_names
    [ *list_containers, "--format", "'{{ .Names }}'" ]
  end

  def remove_container(version:)
    pipe \
      container_id_for(container_name: container_name(version)),
      xargs(docker(:container, :rm))
  end

  def rename_container(version:, new_version:)
    docker :rename, container_name(version), container_name(new_version)
  end

  def remove_containers
    docker :container, :prune, "--force", *filter_args
  end

  def list_images
    docker :image, :ls, config.repository
  end

  def remove_images
    docker :image, :prune, "--all", "--force", *filter_args
  end

  def tag_current_as_latest
    docker :tag, config.absolute_image, config.latest_image
  end


  private
    def container_name(version = nil)
      [ config.service, role, config.destination, version || config.version ].compact.join("-")
    end

    def filter_args(status: nil)
      argumentize "--filter", filters(status: status)
    end

    def filters(status: nil)
      [ "label=service=#{config.service}" ].tap do |filters|
        filters << "label=destination=#{config.destination}" if config.destination
        filters << "label=role=#{role}" if role
        filters << "status=#{status}" if status
      end
    end
end
