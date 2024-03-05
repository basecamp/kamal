class Kamal::Commands::Healthcheck < Kamal::Commands::Base
  def run
    primary = config.role(config.primary_role)

    docker :run,
      "--detach",
      "--name", container_name_with_version,
      "--publish", "#{exposed_port}:#{config.healthcheck["port"]}",
      "--label", "service=#{config.healthcheck_service}",
      "-e", "KAMAL_CONTAINER_NAME=\"#{config.healthcheck_service}\"",
      *primary.env_args,
      *primary.health_check_args(cord: false),
      *config.volume_args,
      *primary.option_args,
      config.absolute_image,
      primary.cmd
  end

  def status
    pipe container_id, xargs(docker(:inspect, "--format", DOCKER_HEALTH_STATUS_FORMAT))
  end

  def container_health_log
    pipe container_id, xargs(docker(:inspect, "--format", DOCKER_HEALTH_LOG_FORMAT))
  end

  def logs
    pipe container_id, xargs(docker(:logs, "--tail", log_lines, "2>&1"))
  end

  def stop
    pipe container_id, xargs(docker(:stop))
  end

  def remove
    pipe container_id, xargs(docker(:container, :rm))
  end

  private
    def container_name_with_version
      "#{config.healthcheck_service}-#{config.version}"
    end

    def container_id
      container_id_for(container_name: container_name_with_version)
    end

    def health_url
      "http://localhost:#{exposed_port}#{config.healthcheck["path"]}"
    end

    def exposed_port
      config.healthcheck["exposed_port"]
    end

    def log_lines
      config.healthcheck["log_lines"]
    end
end
