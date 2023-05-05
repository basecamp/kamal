class Mrsk::Commands::Hook < Mrsk::Commands::Base
  def run(hook, **details)
    [ ".mrsk/hooks/#{hook}", env: tags(**details).env ]
  end

  def hook_exists?(hook)
    Pathname.new(hook_file(hook)).exist?
  end

  private
    def hook_file(hook)
      ".mrsk/hooks/#{hook}"
    end
end
