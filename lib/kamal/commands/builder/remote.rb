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

  private
    def builder_name
      "kamal-remote-#{driver}-#{remote.gsub(/[^a-z0-9_-]/, "-")}"
    end

    def create_remote_context
      docker :context, :create, builder_name, "--description", "'#{builder_name} host'", "--docker", "'host=#{remote}'"
    end

    def remove_remote_context
      docker :context, :rm, builder_name
    end

    def create_buildx
      docker :buildx, :create, "--name", builder_name, builder_name
    end

    def remove_buildx
      docker :buildx, :rm, builder_name
    end
end
