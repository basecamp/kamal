class Mrsk::Commands::App < Mrsk::Commands::Base
  def run(role: :web)
    role = config.role(role)

    docker :run,
      "-d",
      "--restart unless-stopped",
      "--log-driver", "local",
      "--name", service_with_version,
      *role.env_args,
      *config.volume_args,
      *role.label_args,
      config.absolute_image,
      role.cmd
  end

  def start
    docker :start, service_with_version
  end

  def stop
    pipe current_container_id, xargs(docker(:stop))
  end

  def info
    docker :ps, *service_filter
  end


  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      current_container_id,
      "xargs docker logs#{" --since #{since}" if since}#{" -n #{lines}" if lines} 2>&1",
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh \
      pipe(
        current_container_id,
        "xargs docker logs -t -n 10 -f 2>&1",
        (%(grep "#{grep}") if grep)
      ),
      host: host
  end


  def execute_in_existing_container(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      config.service_with_version,
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
    docker :ps, "-q", *service_filter
  end

  def container_id_for(container_name:)
    docker :container, :ls, "-a", "-f", "name=#{container_name}", "-q"
  end

  def current_running_version
    # FIXME: Find more graceful way to extract the version from "app-version" than using sed and tail!
    pipe \
      docker(:ps, "--filter", "label=service=#{config.service}", "--format", '"{{.Names}}"'),
      %(sed 's/-/\\n/g'),
      "tail -n 1"
  end

  def most_recent_version_from_available_images
    pipe \
      docker(:image, :ls, "--format", '"{{.Tag}}"', config.repository),
      "head -n 1"
  end


  def list_containers
    docker :container, :ls, "-a", *service_filter
  end

  def remove_container(version:)
    pipe \
      container_id_for(container_name: service_with_version(version)),
      xargs(docker(:container, :rm))
  end

  def remove_containers
    docker :container, :prune, "-f", *service_filter
  end

  def list_images
    docker :image, :ls, config.repository
  end

  def remove_images
    docker :image, :prune, "-a", "-f", *service_filter
  end


  private
    def service_with_version(version = nil)
      if version
        "#{config.service}-#{version}"
      else
        config.service_with_version
      end
    end

    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end
end
