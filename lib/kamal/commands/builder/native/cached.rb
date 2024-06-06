class Kamal::Commands::Builder::Native::Cached < Kamal::Commands::Builder::Native
  def create
    docker :buildx, :create, "--name", builder_name, "--use", "--driver=docker-container"
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

  def context_hosts
    docker :buildx, :inspect, builder_name, "> /dev/null"
  end

  private
    def builder_name
      "kamal-#{config.service}-native-cached"
    end
end
