require_relative "setup"

namespace :mrsk do
  namespace :server do
    desc "Setup Docker on the remote servers"
    task :bootstrap do
      on(MRSK.config.hosts) { execute "which docker || apt-get install docker.io -y" }
    end
  end
end
