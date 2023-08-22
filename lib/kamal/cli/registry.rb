class Kamal::Cli::Registry < Kamal::Cli::Base
  desc "login", "Log in to registry locally and remotely"
  def login
    run_locally    { execute *KAMAL.registry.login }
    on(KAMAL.hosts) { execute *KAMAL.registry.login }
  # FIXME: This rescue needed?
  rescue ArgumentError => e
    puts e.message
  end

  desc "logout", "Log out of registry remotely"
  def logout
    on(KAMAL.hosts) { execute *KAMAL.registry.logout }
  # FIXME: This rescue needed?
  rescue ArgumentError => e
    puts e.message
  end
end
