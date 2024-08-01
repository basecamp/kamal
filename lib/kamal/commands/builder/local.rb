class Kamal::Commands::Builder::Local < Kamal::Commands::Builder::Base
  def create
    docker :buildx, :create, "--name", builder_name, "--driver=#{driver}" unless docker_driver?
  end

  def remove
    docker :buildx, :rm, builder_name unless docker_driver?
  end

  private
    def builder_name
      "kamal-local-#{driver}"
    end

    def platform_options
      if multiarch?
        if local_arch
          [ "--platform", "linux/#{local_arch}" ]
        else
          [ "--platform", "linux/amd64,linux/arm64" ]
        end
      end
    end
end
