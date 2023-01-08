require_relative "setup"

app = Mrsk::Commands::App.new(MRSK_CONFIG)

namespace :mrsk do
  namespace :server do
    desc "Setup Docker on the remote servers"
    task :bootstrap do
      # FIXME: Detect when apt-get is not available and use the appropriate alternative
      on(MRSK_CONFIG.servers) { execute "apt-get install docker.io -y" }
    end
  end
end
