class Kamal::Commands::Registry < Kamal::Commands::Base
  delegate :registry, to: :config
  delegate :local?, :local_port, to: :registry

  def login
    docker :login,
      registry.server,
      "-u", sensitive(Kamal::Utils.escape_shell_value(registry.username)),
      "-p", sensitive(Kamal::Utils.escape_shell_value(registry.password))
  end

  def logout
    docker :logout, registry.server
  end

  def setup
    combine \
      docker(:start, "kamal-docker-registry"),
      docker(:run, "--detach", "-p", "#{local_port}:5000", "--name", "kamal-docker-registry", "registry:2"),
      by: "||"
  end

  def remove
    combine \
      docker(:stop, "kamal-docker-registry"),
      docker(:rm, "kamal-docker-registry"),
      by: "&&"
  end

  def logout
    docker :logout, registry.server
  end

  def tunnel(host)
    run_over_ssh "-R", "#{local_port}:localhost:#{local_port}", host: host
  end
end
