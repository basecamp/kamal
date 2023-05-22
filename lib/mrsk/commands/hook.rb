class Mrsk::Commands::Hook < Mrsk::Commands::Base
  def run(hook, **details)
    [ hook_file(hook), env: tags(**details).env ]
  end

  def hook_exists?(hook)
    Pathname.new(hook_file(hook)).exist?
  end

  private
    def hook_file(hook)
      "#{config.hooks_path}/#{hook}"
    end
end
