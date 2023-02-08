class Mrsk::Commands::Builder::Native < Mrsk::Commands::Builder::Base
  def create
    # No-op on native
  end

  def remove
    # No-op on native
  end

  def push
    combine \
      docker(:build, *build_tags, *build_args, *build_secrets, "."),
      docker(:push, config.absolute_image)
  end

  def info
    # No-op on native
  end
end
