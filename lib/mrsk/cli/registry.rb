require "mrsk/cli/base"

class Mrsk::Cli::Registry < Mrsk::Cli::Base
  desc "login", "Login to the registry locally and remotely"
  def login
    run_locally           { execute *MRSK.registry.login }
    on(MRSK.config.hosts) { execute *MRSK.registry.login }
  end

  desc "logout", "Logout of the registry remotely"
  def logout
    on(MRSK.config.hosts) { execute *MRSK.registry.logout }
  end
end
