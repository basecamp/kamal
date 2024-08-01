class Kamal::Commands::Builder::Hybrid < Kamal::Commands::Builder::Remote
  def create
    combine \
      create_local_buildx,
      create_remote_context,
      append_remote_buildx
  end

  private
    def builder_name
      "kamal-hybrid-#{driver}-#{local_arch}-#{remote_arch}-#{remote_host.gsub(/[^a-z0-9_-]/, "-")}"
    end

    def create_local_buildx
      docker :buildx, :create, "--name", builder_name, "--platform", "linux/#{local_arch}", "--driver=#{driver}"
    end

    def append_remote_buildx
      docker :buildx, :create, "--append", "--name", builder_name, builder_name, "--platform", "linux/#{remote_arch}"
    end

    def platform
      "linux/#{local_arch},linux/#{remote_arch}"
    end
end
