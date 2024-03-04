class Kamal::Commands::Builder::Native::Cached < Kamal::Commands::Builder::Native
  def create
    docker :buildx, :create, "--use", "--driver=docker-container"
  end

  def remove
    docker :buildx, :rm, builder_name
  end

  private
    def build_and_push
      docker :buildx, :build,
        "--push",
        *build_options,
        build_context
    end
end
