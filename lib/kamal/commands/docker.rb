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

  def root?
    [ '[ "${EUID:-$(id -u)}" -eq 0 ]' ]
  end

  def in_docker_group?
    [ 'id -nG "${USER:-$(id -un)}" | grep -qw docker' ]
  end

  def add_to_docker_group
    [ 'sudo -n usermod -aG docker "${USER:-$(id -un)}"' ]
  end

  def refresh_session
    [ "kill -HUP $PPID" ]
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
