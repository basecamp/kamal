class Mrsk::Commands::Registry < Mrsk::Commands::Base
  delegate :registry, to: :config

  def login
    docker :login, registry["server"], "-u", redact(registry["username"]), "-p", redact(lookup_password)
  end

  def logout
    docker :logout, registry["server"]
  end

  private
    def lookup_password
      if registry["password"].is_a?(Array)
        ENV.fetch(registry["password"].first).dup
      else
        registry["password"]
      end
    end
end
