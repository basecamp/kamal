class Kamal::Cli::Registry < Kamal::Cli::Base
  desc "login", "Log in to registry locally and remotely"
  option :skip_local, aliases: "-L", type: :boolean, default: false, desc: "Skip local login"
  option :skip_remote, aliases: "-R", type: :boolean, default: false, desc: "Skip remote login"
  def login
    ensure_docker_installed unless options[:skip_local]

    run_locally    { execute *KAMAL.registry.login } unless options[:skip_local]
    on(KAMAL.hosts) { execute *KAMAL.registry.login } unless options[:skip_remote]
  end

  desc "logout", "Log out of registry locally and remotely"
  option :skip_local, aliases: "-L", type: :boolean, default: false, desc: "Skip local login"
  option :skip_remote, aliases: "-R", type: :boolean, default: false, desc: "Skip remote login"
  def logout
    run_locally    { execute *KAMAL.registry.logout } unless options[:skip_local]
    on(KAMAL.hosts) { execute *KAMAL.registry.logout } unless options[:skip_remote]
  end
end
