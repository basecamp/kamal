class Mrsk::Commands::Registry < Mrsk::Commands::Base
  delegate :registry, to: :config

  def login
    docker :login, registry["server"], "-u", redact(registry["username"]), "-p", redact(registry["password"])
  end

  def logout
    docker :logout, registry["server"]
  end
end
