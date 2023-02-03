class Mrsk::Cli::Server < Mrsk::Cli::Base
  desc "bootstrap", "Ensure Docker is installed on the servers"
  def bootstrap
    on(MRSK.hosts + MRSK.accessory_hosts) { execute "which docker || (apt-get update -y && apt-get install docker.io -y)" }
  end
end
