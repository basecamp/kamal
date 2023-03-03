class Mrsk::Commands::App < Mrsk::Commands::Base
  def run(role: :web)
    role = config.role(role)

    docker :run,
      "--detach",
      "--restart unless-stopped",
      "--log-opt", "max-size=#{MAX_LOG_SIZE}",
      "--name", service_with_version_and_destination,
      *role.env_args,
      *config.volume_args,
      *role.label_args,
      config.absolute_image,
      role.cmd
  end

  def start
    docker :start, service_with_version_and_destination
  end

  def stop(version: nil)
    pipe \
      version ? container_id_for_version(version) : current_container_id,
      xargs(docker(:stop))
  end

  def info
    docker :ps, *service_filter_with_destination
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
      service_with_version_and_destination,
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
    docker :ps, "--quiet", *service_filter_with_destination
  end

  def current_running_version
    # FIXME: Find more graceful way to extract the version from "app-version" than using sed and tail!
    pipe \
      docker(:ps, *service_filter_with_destination, "--format", '"{{.Names}}"'),
      %(sed 's/-/\\n/g'),
      "tail -n 1"
  end

  def most_recent_version_from_available_images
    pipe \
      docker(:image, :ls, "--format", '"{{.Tag}}"', config.repository),
      "head -n 1"
  end

  def all_versions_from_available_containers
    pipe \
      docker(:image, :ls, "--format", '"{{.Tag}}"', config.repository),
      "head -n 1"
  end


  def list_containers
    docker :container, :ls, "--all", *service_filter_with_destination
  end

  def list_container_names
    [ *list_containers, "--format", "'{{ .Names }}'" ]
  end

  def remove_container(version:)
    pipe \
      container_id_for(container_name: service_with_version_and_destination(version)),
      xargs(docker(:container, :rm))
  end

  def remove_containers
    docker :container, :prune, "--force", *service_filter_with_destination
  end

  def list_images
    docker :image, :ls, config.repository
  end

  def remove_images
    docker :image, :prune, "--all", "--force", *service_filter
  end


  private
    def service_with_version_and_destination(version = nil)
      [ config.service, config.destination, version || config.version ].compact.join("-")
    end

    def container_id_for_version(version)
      container_id_for(container_name: service_with_version_and_destination(version))
    end

    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end

    def service_filter_with_destination
      if config.destination
        service_filter << "label=destination=#{config.destination}"
      else
        service_filter
      end
    end
end
