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
      "--name", container_name,
      "-e", "MRSK_CONTAINER_NAME=\"#{container_name}\"",
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

  def stop(version: nil)
    pipe \
      version ? container_id_for_version(version) : current_container_id,
      xargs(config.stop_wait_time ? docker(:stop, "-t", config.stop_wait_time) : docker(:stop))
  end

  def health(version: nil)
    pipe \
      version ? container_id_for_version(version) : current_container_id,
      xargs(docker(:inspect, "-f", "'{{ json .State.Health }}'"))
  end

  def info
    docker :ps, *filter_args
  end

  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      current_container_id,
      "xargs docker logs#{" --since #{since}" if since}#{" --tail #{lines}" if lines} 2>&1",
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh \
      pipe(
        current_container_id,
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


  def current_container_id
    docker :ps, "--quiet", "--latest", *filter_args
  end

  def container_id_for_version(version)
    container_id_for(container_name: container_name(version))
  end

  def current_running_version
    # FIXME: Find more graceful way to extract the version from "app-version" than using sed and tail!
    pipe \
      docker(:ps, *filter_args, "--format", '"{{.Names}}"', "--latest"),
      %(sed 's/-/\\n/g'),
      "tail -n 1"
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


  private
    def container_name(version = nil)
      [ config.service, role, config.destination, version || config.version ].compact.join("-")
    end

    def filter_args
      argumentize "--filter", filters
    end

    def filters
      [ "label=service=#{config.service}", "status=running" ].tap do |filters|
        filters << "label=destination=#{config.destination}" if config.destination
        filters << "label=role=#{role}" if role
      end
    end
end
