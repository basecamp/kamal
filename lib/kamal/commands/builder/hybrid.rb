class Kamal::Commands::Builder::Hybrid < Kamal::Commands::Builder::Base
  def create
    combine \
      create_local_buildx,
      create_remote_context,
      append_remote_buildx
  end

  def context_hosts
    chain \
      context_host(builder_name)
  end

  def config_context_hosts
    [ remote_host ].compact
  end

  private
    def builder_name
      "kamal-hybrid-#{remote_host.gsub(/[^a-z0-9_-]/, "-")}-#{local_arch}-#{remote_arch}"
    end

    def create_local_buildx
      docker :buildx, :create, "--name", builder_name, "--platform", "linux/#{local_arch}", "--driver=docker-container"
    end

    def append_remote_buildx
      docker :buildx, :create, "--append", "--name", builder_name, builder_name, "--platform", "linux/#{remote_arch}"
    end

    def platform_options
      [ "--platform", "linux/#{local_arch},linux/#{remote_arch}" ]
    end
end
