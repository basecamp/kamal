require_relative "setup"

namespace :mrsk do
  namespace :server do
    desc "Setup Docker on the remote servers"
    task :bootstrap do
      # FIXME: Detect when apt-get is not available and use the appropriate alternative
      on(MRSK_CONFIG.hosts) { execute "apt-get install docker.io -y" }
    end
  end
end
