class Kamal::Commands::Builder::Multiarch::Remote < Kamal::Commands::Builder::Multiarch
  def create
    combine \
      create_contexts,
      create_local_buildx,
      append_remote_buildx
  end

  def remove
    combine \
      remove_contexts,
      super
  end

  def context_hosts
    chain \
      context_host(builder_name_with_arch(local_arch)),
      context_host(builder_name_with_arch(remote_arch))
  end

  def config_context_hosts
    [ local_host, remote_host ].compact
  end

  private
    def builder_name
      super + "-remote"
    end

    def builder_name_with_arch(arch)
      "#{builder_name}-#{arch}"
    end

    def create_local_buildx
      docker :buildx, :create, "--name", builder_name, builder_name_with_arch(local_arch), "--platform", "linux/#{local_arch}"
    end

    def append_remote_buildx
      docker :buildx, :create, "--append", "--name", builder_name, builder_name_with_arch(remote_arch), "--platform", "linux/#{remote_arch}"
    end

    def create_contexts
      combine \
        create_context(local_arch, local_host),
        create_context(remote_arch, remote_host)
    end

    def create_context(arch, host)
      docker :context, :create, builder_name_with_arch(arch), "--description", "'#{builder_name} #{arch} native host'", "--docker", "'host=#{host}'"
    end

    def remove_contexts
      combine \
        remove_context(local_arch),
        remove_context(remote_arch)
    end

    def remove_context(arch)
      docker :context, :rm, builder_name_with_arch(arch)
    end
end
