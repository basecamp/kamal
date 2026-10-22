class Kamal::Cli::Alias::Command < Thor::DynamicCommand
  # Thor only gets here when no built-in command matches. An alias in the config
  # comes next, then an external command, then Thor's error.
  def run(instance, args = [])
    external = Kamal::Cli::Main.external_command(name)

    if (command = configured_alias(external))
      KAMAL.reset
      Kamal::Cli::Main.start(Shellwords.split(command) + ARGV[1..-1])
    elsif external
      exec [ external, external ], *given_args(instance)
    else
      super
    end
  end

  private
    # There's no alias without a config file, and an external command doesn't need one
    def configured_alias(external)
      KAMAL.resolve_alias(name) unless external && !KAMAL.config_file?
    end

    # The arguments after the command name, as given, options included
    def given_args(instance)
      instance.instance_variable_get("@_initializer")[1]
    end
end
