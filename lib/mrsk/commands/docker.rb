class Mrsk::Commands::Docker < Mrsk::Commands::Base
  # Install Docker using the https://github.com/docker/docker-install convenience script.
  def install
    pipe [ :curl, "-fsSL", "https://get.docker.com" ], :sh
  end

  # Checks the Docker client version. Fails if Docker is not installed.
  def installed?
    docker "-v"
  end

  # Checks the Docker server version. Fails if Docker is not running.
  def running?
    docker :version
  end

  # Do we have superuser access to install Docker and start system services?
  def superuser?
    [ '[ "${EUID:-$(id -u)}" -eq 0 ]' ]
  end
end
