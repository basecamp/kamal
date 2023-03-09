class Mrsk::Commands::Builder::Native < Mrsk::Commands::Builder::Base
  def create
    # No-op on native
  end

  def remove
    # No-op on native
  end

  def push
    combine \
      docker(:build, *build_options, build_context),
      docker(:push, config.absolute_image)
  end

  def info
    # No-op on native
  end
end
