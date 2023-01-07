require_relative "setup"

registry = Mrsk::Commands::Registry.new(MRSK_CONFIG)

namespace :mrsk do
  namespace :registry do
    desc "Login to the registry locally and remotely"
    task :login do
      run_locally             { execute registry.login }
      on(MRSK_CONFIG.servers) { execute registry.login }
    end
  end
end
