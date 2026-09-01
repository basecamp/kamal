class Kamal::Commands::Builder::Local < Kamal::Commands::Builder::Base
  def create
    return if docker_driver?

    docker :buildx, :create, "--name", builder_name, "--driver=#{driver}", *driver_options
  end

  def remove
    docker :buildx, :rm, builder_name unless docker_driver?
  end

  private
    def builder_name
      if registry_config.local?
        "kamal-local-registry-#{driver}-#{registry_digest}"
      else
        "kamal-local-#{driver}-#{registry_digest}"
      end
    end
end
