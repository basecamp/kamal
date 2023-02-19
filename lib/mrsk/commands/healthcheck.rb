class Mrsk::Commands::Healthcheck < Mrsk::Commands::Base
  EXPOSED_PORT = 3999

  def run
    web = config.role(:web)

    docker :run,
      "-d",
      "--name", container_name_with_version,
      "-p", "#{EXPOSED_PORT}:#{config.healthcheck["port"]}",
      "--label", "service=#{container_name}",
      *web.env_args,
      *config.volume_args,
      config.absolute_image,
      web.cmd
  end

  def curl
    [ :curl, "--silent", "--output", "/dev/null", "--write-out", "'%{http_code}'", health_url ]
  end

  def logs
    pipe container_id, xargs(docker(:logs, "2>&1"))
  end

  def stop
    pipe container_id, xargs(docker(:stop))
  end

  def remove
    pipe container_id, xargs(docker(:container, :rm))
  end

  private
    def container_name
      "healthcheck-#{config.service}"
    end

    def container_name_with_version
      "healthcheck-#{config.service_with_version}"
    end

    def container_id
      container_id_for(container_name: container_name)
    end

    def health_url
      "http://localhost:#{EXPOSED_PORT}#{config.healthcheck["path"]}"
    end
end
