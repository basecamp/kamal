require "mrsk/commands/builder/base"

class Mrsk::Commands::Builder::Native < Mrsk::Commands::Builder::Base
  def create
    # No-op on native
  end

  def remove
    # No-op on native
  end

  def push
    combine \
      docker(:build, "-t", *build_args, config.absolute_image, "."),
      docker(:push, config.absolute_image)
  end

  def info
    # No-op on native
  end
end
