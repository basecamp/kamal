class Kamal::Commands::Builder::Multiarch < Kamal::Commands::Builder::Base
  def create
    docker :buildx, :create, "--use", "--name", builder_name
  end

  def remove
    docker :buildx, :rm, builder_name
  end

  def info
    combine \
      docker(:context, :ls),
      docker(:buildx, :ls)
  end

  private
    def builder_name
      "kamal-#{config.service}-multiarch"
    end

    def platform_names
      if local_arch
        "linux/#{local_arch}"
      else
        "linux/amd64,linux/arm64"
      end
    end

    def build_and_push
      docker :buildx, :build,
        "--push",
        "--platform", platform_names,
        "--builder", builder_name,
        *build_options,
        build_context
    end
end
