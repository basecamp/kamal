class Mrsk::Commands::Registry < Mrsk::Commands::Base
  delegate :registry, to: :config

  def login
    docker :login, registry["server"], "-u", sensitive(lookup("username")), "-p", sensitive(lookup("password"))
  end

  def logout
    docker :logout, registry["server"]
  end

  private
    def lookup(key)
      if registry[key].is_a?(Array)
        ENV.fetch(registry[key].first).dup
      else
        registry[key]
      end
    end
end
