class Kamal::Commands::Builder::Native::Remote < Kamal::Commands::Builder::Native
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
    context_host(builder_name_with_arch)
  end

  def config_context_hosts
    [ remote_host ]
  end


  private
    def builder_name
      "kamal-#{config.service}-native-remote"
    end

    def builder_name_with_arch
      "#{builder_name}-#{remote_arch}"
    end

    def platform
      "linux/#{remote_arch}"
    end

    def create_context
      docker :context, :create,
        builder_name_with_arch, "--description", "'#{builder_name} #{remote_arch} native host'", "--docker", "'host=#{remote_host}'"
    end

    def remove_context
      docker :context, :rm, builder_name_with_arch
    end

    def create_buildx
      docker :buildx, :create, "--name", builder_name, builder_name_with_arch, "--platform", platform
    end

    def remove_buildx
      docker :buildx, :rm, builder_name
    end
end
