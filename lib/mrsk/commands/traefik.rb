require "mrsk/commands/base"

class Mrsk::Commands::Traefik < Mrsk::Commands::Base
  def run
    docker :run, "--name traefik",
      "-d",
      "--restart unless-stopped",
      "-p 80:80",
      "-v /var/run/docker.sock:/var/run/docker.sock",
      "traefik",
      "--providers.docker",
      "--log.level=DEBUG",
      *config.traefik_args
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
      docker(:logs, "traefik", (" --since #{since}" if since), (" -n #{lines}" if lines), "-t", "2>&1"),
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh pipe(
      docker(:logs, "traefik", "-t", "-n", "10", "-f", "2>&1"),
      (%(grep "#{grep}") if grep)
    ).join(" "), host: host
  end

  def remove_container
    docker :container, :prune, "-f", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def remove_image
    docker :image, :prune, "-a", "-f", "--filter", "label=org.opencontainers.image.title=Traefik"
  end
end
