class Kamal::Commands::Builder::Hybrid < Kamal::Commands::Builder::Remote
  def create
    combine \
      create_local_buildx,
      create_remote_context,
      append_remote_buildx
  end

  private
    def builder_name
      "kamal-hybrid-#{driver}-#{remote.gsub(/[^a-z0-9_-]/, "-")}"
    end

    def create_local_buildx
      docker :buildx, :create, *platform_options(local_arches), "--name", builder_name, "--driver=#{driver}"
    end

    def append_remote_buildx
      docker :buildx, :create, *platform_options(remote_arches), "--append", "--name", builder_name, remote_context_name
    end
end
