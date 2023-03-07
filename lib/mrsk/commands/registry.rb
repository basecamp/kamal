class Mrsk::Commands::Registry < Mrsk::Commands::Base
  delegate :registry, to: :config

  def login
    docker :login, registry["server"], "-u", redact_credentials("username"), "-p", redact_credentials("password")
  end

  def logout
    docker :logout, registry["server"]
  end

  private
    def redact_credentials(key)
      value = if registry[key].is_a?(Array)
          ENV.fetch(registry[key].first).dup
        else
          registry[key]
        end

      redact(value)
    end
end
