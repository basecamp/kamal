require "mrsk/commands/base"

class Mrsk::Commands::Registry < Mrsk::Commands::Base
  delegate :registry, to: :config

  def login
    docker :login, registry["server"], "-u", Mrsk::Utils.redact(registry["username"]), "-p", Mrsk::Utils.redact(registry["password"])
  end

  def logout
    docker :logout, registry["server"]
  end
end
