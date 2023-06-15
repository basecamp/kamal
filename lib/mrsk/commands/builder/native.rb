class Mrsk::Commands::Builder::Native < Mrsk::Commands::Builder::Base
  def create
    # No-op on native without cache

    if config.builder.cache?
      docker :buildx, :create, "--use", "--driver=docker-container"
    end
  end

  def remove
    # No-op on native without cache

    if config.builder.cache?
      docker :buildx, :rm, builder_name
    end
  end

  def push
    if config.builder.cache?
      docker :buildx, :build,
        "--push",
        *build_options,
        build_context
    else
      combine \
        docker(:build, *build_options, build_context),
        docker(:push, config.absolute_image),
        docker(:push, config.latest_image)
    end
  end

  def info
    # No-op on native
  end
end
