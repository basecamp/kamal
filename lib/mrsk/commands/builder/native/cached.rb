class Mrsk::Commands::Builder::Native::Cached < Mrsk::Commands::Builder::Native
  def create
    docker :buildx, :create, "--use", "--driver=docker-container"
  end

  def remove
    docker :buildx, :rm, builder_name
  end

  def push
    docker :buildx, :build,
      "--push",
      *build_options,
      build_context
  end
end
