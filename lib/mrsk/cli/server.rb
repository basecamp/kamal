require "mrsk/cli/base"

class Mrsk::Cli::Server < Mrsk::Cli::Base
  desc "bootstrap", "Ensure Docker is installed on the servers"
  def bootstrap
    on(MRSK.config.hosts) { execute "which docker || apt-get install docker.io -y" }
  end
end
