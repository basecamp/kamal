class Kamal::Commands::Builder::Local < Kamal::Commands::Builder::Base
  def create
    docker :buildx, :create, "--name", builder_name, "--driver=docker-container"
  end

  def remove
    docker :buildx, :rm, builder_name
  end

  def info
    combine \
      docker(:context, :ls),
      docker(:buildx, :ls)
  end

  def push
    docker :buildx, :build,
      "--push",
      *platform_options,
      "--builder", builder_name,
      *build_options,
      build_context
  end

  def context_hosts
    docker :buildx, :inspect, builder_name, "> /dev/null"
  end

  private
    def builder_name
      "kamal-local"
    end

    def platform_options
      if multiarch?
        if local_arch
          [ "--platform", "linux/#{local_arch}" ]
        else
          [ "--platform", "linux/amd64,linux/arm64" ]
        end
      end
    end
end
