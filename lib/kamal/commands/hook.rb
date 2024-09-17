class Kamal::Commands::Hook < Kamal::Commands::Base
  def run(hook, secrets: false, **details)
    env = tags(**details).env
    env.merge!(config.secrets.to_h) if secrets

    [ hook_file(hook), env: env ]
  end

  def hook_exists?(hook)
    Pathname.new(hook_file(hook)).exist?
  end

  private
    def hook_file(hook)
      File.join(config.hooks_path, hook)
    end
end
