class Mrsk::Cli::Registry < Mrsk::Cli::Base
  desc "login", "Log in to registry locally and remotely"
  def login
    run_locally    { execute *MRSK.registry.login }
    on(MRSK.hosts) { execute *MRSK.registry.login }
  # FIXME: This rescue needed?
  rescue ArgumentError => e
    puts e.message
  end

  desc "logout", "Log out of registry remotely"
  def logout
    on(MRSK.hosts) { execute *MRSK.registry.logout }
  # FIXME: This rescue needed?
  rescue ArgumentError => e
    puts e.message
  end
end
