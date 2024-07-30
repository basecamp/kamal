class Kamal::Commands::Hook < Kamal::Commands::Base
  def run(hook, **details)
    [ Kamal::Hooks.file(hook), env: tags(**details).env ]
  end
end
