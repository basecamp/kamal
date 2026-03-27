class Kamal::Cli::Alias::Command < Thor::DynamicCommand
  def run(instance, args = [])
    if (command = KAMAL.resolve_alias(name))
      KAMAL.reset
      Kamal::Cli::Main.start(Shellwords.split(command) + ARGV[1..-1])
    else
      super
    end
  end
end
