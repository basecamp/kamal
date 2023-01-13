require "mrsk/commands/base"

class Mrsk::Commands::Builder::Native < Mrsk::Commands::Base
  def create
    # No-op on native
  end

  def remove
    # No-op on native
  end

  def push
    combine \
      docker(:build, "-t", config.absolute_image, "."),
      docker(:push, config.absolute_image)
  end

  def pull
    docker :pull, config.absolute_image
  end
end
