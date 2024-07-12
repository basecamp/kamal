class Kamal::Commands::Registry < Kamal::Commands::Base
  delegate :registry, to: :config

  def login
    docker :login,
      registry.server,
      "-u", sensitive(Kamal::Utils.escape_shell_value(registry.username)),
      "-p", sensitive(Kamal::Utils.escape_shell_value(registry.password))
  end

  def logout
    docker :logout, registry.server
  end
end
