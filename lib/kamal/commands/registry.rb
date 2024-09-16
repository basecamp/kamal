class Kamal::Commands::Registry < Kamal::Commands::Base
  delegate :registry, to: :config
  delegate :local?, :local_port, to: :registry

  def login(registry_config: nil)
    registry_config ||= config.registry

    return if local?

    docker :login,
      registry_config.server,
      "-u", sensitive(Kamal::Utils.escape_shell_value(registry_config.username)),
      "-p", sensitive(Kamal::Utils.escape_shell_value(registry_config.password))
  end

  def logout(registry_config: nil)
    registry_config ||= config.registry

    docker :logout, registry_config.server
  end

  def setup
    combine \
      docker(:start, "kamal-docker-registry"),
      docker(:run, "--detach", "-p", "127.0.0.1:#{local_port}:5000", "--name", "kamal-docker-registry", "registry:2"),
      by: "||"
  end

  def remove
    combine \
      docker(:stop, "kamal-docker-registry"),
      docker(:rm, "kamal-docker-registry"),
      by: "&&"
  end
end
