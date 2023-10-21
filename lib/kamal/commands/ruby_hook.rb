class Kamal::Commands::RubyHook < Kamal::Commands::Base
  def run(hook, context)
    context.instance_eval(File.read(hook_file(hook)))
  end

  def hook_exists?(hook)
    Pathname.new(hook_file(hook)).exist?
  end

  private
    def hook_file(hook)
      "#{config.hooks_path}/#{hook}.rb"
    end
end
