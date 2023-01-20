require "mrsk/cli/base"

class Mrsk::Cli::Registry < Mrsk::Cli::Base
  desc "login", "Login to the registry locally and remotely"
  def login
    run_locally           { execute *MRSK.registry.login }
    on(MRSK.hosts) { execute *MRSK.registry.login }
  rescue ArgumentError => e
    puts e.message
  end

  desc "logout", "Logout of the registry remotely"
  def logout
    on(MRSK.hosts) { execute *MRSK.registry.logout }
  rescue ArgumentError => e
    puts e.message
  end
end
