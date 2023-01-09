class Mrsk::Commands::App < Mrsk::Commands::Base
  def push
    # TODO: Run 'docker buildx create --use' when needed
    # TODO: Make multiarch an option so Linux users can enjoy speedier builds
    docker :buildx, :build, "--push", "--platform linux/amd64,linux/arm64", "-t", config.absolute_image, "."
  end

  def pull
    docker :pull, config.absolute_image
  end

  def run
    docker :run,
      "-d",
      "--restart unless-stopped",
      "--name", config.service_with_version,
      "-e", redact("RAILS_MASTER_KEY=#{config.master_key}"),
      *config.envs,
      *config.labels,
      config.absolute_image
  end

  def start
    docker :start, config.service_with_version
  end

  def stop
    [ "docker ps -q #{service_filter.join(" ")} | xargs docker stop" ]
  end

  def info
    docker :ps, *service_filter
  end

  def logs
    [ "docker ps -q #{service_filter.join(" ")} | xargs docker logs -f" ]
  end

  def exec(*command)
    docker :exec, 
      "-e", redact("RAILS_MASTER_KEY=#{config.master_key}"),
      *config.envs,
      config.service_with_version,
      *command
  end

  def list_containers
    docker :container, :ls, "-a", *service_filter
  end

  def remove_containers
    docker :container, :prune, "-f", *service_filter
  end

  def remove_images
    docker :image, :prune, "-a", "-f", *service_filter
  end

  private
    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end
end
