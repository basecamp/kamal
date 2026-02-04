class Kamal::Commands::Docker < Kamal::Commands::Base
  # Install Docker using the https://github.com/docker/docker-install convenience script.
  def install
    pipe get_docker, :sh
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
    [ '[ "${EUID:-$(id -u)}" -eq 0 ] || sudo -nl usermod >/dev/null' ]
  end

  # If we're not root and not already in the docker group
  # add us to the docker group and terminate all our current sessions
  def add_group
    [ '[ "${EUID:-$(id -u)}" -eq 0 ] || id -nG "${USER:-$(id -un)}" | grep -qw docker || { sudo -n usermod -aG docker "${USER:-$(id -un)}" && kill -HUP ${PPID:-ps -o ppid= -p $$}; }' ]
  end

  def create_network
    docker :network, :create, :kamal
  end

  private
    def get_docker
      shell \
        any \
          [ :curl, "-fsSL", "https://get.docker.com" ],
          [ :wget, "-O -", "https://get.docker.com" ],
          [ :echo, "\"exit 1\"" ]
    end
end
