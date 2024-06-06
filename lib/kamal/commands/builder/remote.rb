class Kamal::Commands::Builder::Remote < Kamal::Commands::Builder::Base
  def create
    chain \
      create_context,
      create_buildx
  end

  def remove
    chain \
      remove_context,
      remove_buildx
  end

  def info
    chain \
      docker(:context, :ls),
      docker(:buildx, :ls)
  end

  def push
    docker :buildx, :build,
    "--push",
    "--platform", platform,
    "--builder", builder_name,
    *build_options,
    build_context
  end

  def context_hosts
    context_host(builder_name)
  end

  def config_context_hosts
    [ remote_host ]
  end


  private
    def builder_name
      "kamal-remote-#{remote_arch}"
    end

    def platform
      "linux/#{remote_arch}"
    end

    def create_context
      docker :context, :create, builder_name, "--description", "'#{builder_name} host'", "--docker", "'host=#{remote_host}'"
    end

    def remove_context
      docker :context, :rm, builder_name
    end

    def create_buildx
      docker :buildx, :create, "--name", builder_name, builder_name, "--platform", platform
    end

    def remove_buildx
      docker :buildx, :rm, builder_name
    end
end
