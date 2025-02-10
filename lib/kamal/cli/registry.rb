class Kamal::Cli::Registry < Kamal::Cli::Base
  desc "setup", "Setup local registry or log in to remote registry locally and remotely"
  option :skip_local, aliases: "-L", type: :boolean, default: false, desc: "Skip local login"
  option :skip_remote, aliases: "-R", type: :boolean, default: false, desc: "Skip remote login"
  def setup
    ensure_docker_installed unless options[:skip_local]

    if KAMAL.registry.local?
      run_locally    { execute *KAMAL.registry.setup } unless options[:skip_local]
    else
      run_locally    { execute *KAMAL.registry.login } unless options[:skip_local]
      on(KAMAL.hosts) { execute *KAMAL.registry.login } unless options[:skip_remote]
    end
  end

  desc "remove", "Remove local registry or log out of remote registry locally and remotely"
  option :skip_local, aliases: "-L", type: :boolean, default: false, desc: "Skip local login"
  option :skip_remote, aliases: "-R", type: :boolean, default: false, desc: "Skip remote login"
  def remove
    if KAMAL.registry.local?
      run_locally    { execute *KAMAL.registry.remove, raise_on_non_zero_exit: false } unless options[:skip_local]
    else
      run_locally    { execute *KAMAL.registry.logout } unless options[:skip_local]
      on(KAMAL.hosts) { execute *KAMAL.registry.logout } unless options[:skip_remote]
    end
  end
end
