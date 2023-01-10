require_relative "setup"

registry = Mrsk::Commands::Registry.new(MRSK_CONFIG)

namespace :mrsk do
  namespace :registry do
    desc "Login to the registry locally and remotely"
    task :login do
      run_locally           { execute *registry.login }
      on(MRSK_CONFIG.hosts) { execute *registry.login }
    end

    desc "Logout of the registry remotely"
    task :logout do
      on(MRSK_CONFIG.hosts) { execute *registry.logout }
    end
  end
end
