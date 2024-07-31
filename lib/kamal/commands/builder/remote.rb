class Kamal::Commands::Builder::Remote < Kamal::Commands::Builder::Base
  def create
    chain \
      create_remote_context,
      create_buildx
  end

  def remove
    chain \
      remove_remote_context,
      remove_buildx
  end

  def info
    chain \
      docker(:context, :ls),
      docker(:buildx, :ls)
  end

  def push
    docker :build,
      "--push",
      *platform_options,
      "--builder", builder_name,
      *build_options,
      build_context
  end

  private
    def builder_name
      "kamal-remote-#{remote_arch}-#{remote_host.gsub(/[^a-z0-9_-]/, "-")}"
    end

    def create_remote_context
      docker :context, :create, builder_name, "--description", "'#{builder_name} host'", "--docker", "'host=#{remote_host}'"
    end

    def remove_remote_context
      docker :context, :rm, builder_name
    end

    def create_buildx
      docker :buildx, :create, "--name", builder_name, builder_name, "--platform", platform
    end

    def remove_buildx
      docker :buildx, :rm, builder_name
    end

    def platform_options
      [ "--platform", platform ]
    end

    def platform
      "linux/#{remote_arch}"
    end
end
