class Mrsk::Commands::Traefik
  def start
    "docker run --name traefik " + 
      "--rm -d " +
      "-p 80:80 " +
      "-v /var/run/docker.sock:/var/run/docker.sock " +
      "traefik --providers.docker"
  end

  def stop
    "docker container stop traefik"
  end

  def info
    "docker ps --filter name=traefik"
  end
end
