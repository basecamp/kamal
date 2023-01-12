require "mrsk/commands/base"

class Mrsk::Commands::Traefik < Mrsk::Commands::Base
  def run
    docker :run, "--name traefik",
      "-d",
      "--restart unless-stopped",
      "-p 80:80",
      "-v /var/run/docker.sock:/var/run/docker.sock",
      "traefik",
      "--providers.docker"
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

  def logs
    docker :logs, "traefik", "-n", "100", "-t"
  end

  def remove_container
    docker :container, :prune, "-f", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def remove_image
    docker :image, :prune, "-a", "-f", "--filter", "label=org.opencontainers.image.title=Traefik"
  end
end
