require "mrsk/commands/builder/multiarch"

class Mrsk::Commands::Builder::Multiarch::Remote < Mrsk::Commands::Builder::Multiarch
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

  private
    def create_local_buildx
      docker :buildx, :create, "--use", "--name", "mrsk", "mrsk-#{local["arch"]}", "--platform", "linux/#{local["arch"]}"
    end

    def append_remote_buildx
      docker :buildx, :create, "--append", "--name", "mrsk", "mrsk-#{remote["arch"]}", "--platform", "linux/#{remote["arch"]}"
    end

    def create_contexts
      combine \
        create_context(local["arch"], local["host"]),
        create_context(remote["arch"], remote["host"])
    end

    def create_context(arch, host)
      docker :context, :create, "mrsk-#{arch}", "--description", "'MRSK #{arch} Native Host'", "--docker", "'host=#{host}'"
    end

    def remove_contexts
      combine \
        remove_context(local["arch"]),
        remove_context(remote["arch"])
    end

    def remove_context(arch)
      docker :context, :rm, "mrsk-#{arch}"
    end

    def local
      config.builder["local"]
    end

    def remote
      config.builder["remote"]
    end
end
