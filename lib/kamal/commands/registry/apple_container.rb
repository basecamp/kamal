class Kamal::Commands::Registry::AppleContainer < Kamal::Commands::Registry
  def login(registry_config: nil)
    registry_config ||= config.registry

    return if registry_config.local?

    pipe \
      [ :echo, sensitive(Kamal::Utils.escape_shell_value(registry_config.password)) ],
      apple_container(
        :registry, :login,
        *registry_scheme_options(registry_config),
        "--username", sensitive(Kamal::Utils.escape_shell_value(registry_config.username)),
        "--password-stdin",
        server_for(registry_config))
  end

  def logout(registry_config: nil)
    registry_config ||= config.registry

    apple_container :registry, :logout, server_for(registry_config)
  end

  def setup(registry_config: nil)
    registry_config ||= config.registry

    combine \
      apple_container(:start, LOCAL_REGISTRY_CONTAINER),
      apple_container(:run, "--detach", "-p", "127.0.0.1:#{registry_config.local_port}:5000", "--name", LOCAL_REGISTRY_CONTAINER, "registry:3"),
      by: "||"
  end

  def remove
    combine \
      apple_container(:stop, LOCAL_REGISTRY_CONTAINER),
      apple_container(:delete, LOCAL_REGISTRY_CONTAINER),
      by: "&&"
  end

  private
    def registry_scheme_options(registry_config)
      [ "--scheme", registry_config.scheme ] if registry_config.scheme.present?
    end

    # `container` has no implicit Docker Hub default.
    def server_for(registry_config)
      registry_config.server.presence || "docker.io"
    end
end
