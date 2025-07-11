class Kamal::Commands::Registry < Kamal::Commands::Base
  def login(registry_config: nil)
    registry_config ||= config.registry

    pipe \
      [ :printf, "%s", registry_config.password ],
      docker(:login, registry_config.server, "-u", sensitive(Kamal::Utils.escape_shell_value(registry_config.username)), "--password-stdin")
  end

  def logout(registry_config: nil)
    registry_config ||= config.registry

    docker :logout, registry_config.server
  end
end
