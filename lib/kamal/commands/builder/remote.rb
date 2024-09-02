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

  def inspect_builder
    combine \
      combine inspect_buildx, inspect_remote_context,
      [ "(echo no compatible builder && exit 1)" ],
      by: "||"
  end

  private
    def builder_name
      "kamal-remote-#{remote.gsub(/[^a-z0-9_-]/, "-")}"
    end

    def remote_context_name
      "#{builder_name}-context"
    end

    def inspect_buildx
      pipe \
        docker(:buildx, :inspect, builder_name),
        grep("-q", "Endpoint:.*#{remote_context_name}")
    end

    def inspect_remote_context
      pipe \
        docker(:context, :inspect, remote_context_name, "--format", ENDPOINT_DOCKER_HOST_INSPECT),
        grep("-xq", remote)
    end

    def create_remote_context
      docker :context, :create, remote_context_name, "--description", "'#{builder_name} host'", "--docker", "'host=#{remote}'"
    end

    def remove_remote_context
      docker :context, :rm, remote_context_name
    end

    def create_buildx
      docker :buildx, :create, "--name", builder_name, remote_context_name
    end

    def remove_buildx
      docker :buildx, :rm, builder_name
    end
end
