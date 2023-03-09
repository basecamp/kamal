class Mrsk::Commands::Traefik < Mrsk::Commands::Base
  delegate :argumentize_for_cmd, to: Mrsk::Utils

  CONTAINER_PORT = 80

  def run
    docker :run, "--name traefik",
      "--detach",
      "--restart", "unless-stopped",
      "--log-opt", "max-size=#{MAX_LOG_SIZE}",
      "--publish", port,
      "--volume", "/var/run/docker.sock:/var/run/docker.sock",
      "traefik",
      "--providers.docker",
      "--log.level=DEBUG",
      *cmd_args
  end

  def start
    docker :container, :start, "traefik"
  end

  def stop
    docker :container, :stop, "traefik"
  end

  def info
    docker :ps, "--filter", "name=traefik"
  end

  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      docker(:logs, "traefik", (" --since #{since}" if since), (" --tail #{lines}" if lines), "--timestamps", "2>&1"),
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh pipe(
      docker(:logs, "traefik", "--timestamps", "--tail", "10", "--follow", "2>&1"),
      (%(grep "#{grep}") if grep)
    ).join(" "), host: host
  end

  def remove_container
    docker :container, :prune, "--force", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def remove_image
    docker :image, :prune, "--all", "--force", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def port    
    "#{host_port}:#{CONTAINER_PORT}"
  end

  private
    def cmd_args
      if args = config.raw_config.dig(:traefik, "args")
        argumentize_for_cmd args
      else
        []
      end
    end

    def host_port
      config.raw_config.dig(:traefik, "host_port") || CONTAINER_PORT
    end
end
