require_relative "setup"

namespace :mrsk do
  namespace :registry do
    desc "Login to the registry locally and remotely"
    task :login do
      run_locally           { execute *MRSK.registry.login }
      on(MRSK.config.hosts) { execute *MRSK.registry.login }
    end

    desc "Logout of the registry remotely"
    task :logout do
      on(MRSK.config.hosts) { execute *MRSK.registry.logout }
    end
  end
end
