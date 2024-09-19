class Kamal::Commands::Hook < Kamal::Commands::Base
  def run(hook)
    [ hook_file(hook) ]
  end

  def env(secrets: false, **details)
    tags(**details).env.tap do |env|
      env.merge!(config.secrets.to_h) if secrets
    end
  end

  def hook_exists?(hook)
    Pathname.new(hook_file(hook)).exist?
  end

  private
    def hook_file(hook)
      File.join(config.hooks_path, hook)
    end
end
