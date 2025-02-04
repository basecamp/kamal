class Kamal::Cli::Alias::Command < Thor::DynamicCommand
  def run(instance, args = [])
    if (_alias = KAMAL.config.aliases[name])
      KAMAL.reset
      Kamal::Cli::Main.start(Shellwords.split(_alias.command) + ARGV[1..-1])
    else
      super
    end
  end
end
