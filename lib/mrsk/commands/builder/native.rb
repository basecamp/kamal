require "mrsk/commands/base"

class Mrsk::Commands::Builder::Native < Mrsk::Commands::Base
  def create
    # No op on native
  end

  def remove
    # No op on native
  end

  def push
    docker :build, "--push", "-t", config.absolute_image, "."
  end

  def pull
    docker :pull, config.absolute_image
  end
end
