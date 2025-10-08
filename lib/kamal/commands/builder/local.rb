class Kamal::Commands::Builder::Local < Kamal::Commands::Builder::Base
  def create
    return if docker_driver?

    options =
      if KAMAL.registry.local?
        "--driver=#{driver} --driver-opt network=host"
      else
        "--driver=#{driver}"
      end

    docker :buildx, :create, "--name", builder_name, options
  end

  def remove
    docker :buildx, :rm, builder_name unless docker_driver?
  end

  private
    def builder_name
      if KAMAL.registry.local?
        "kamal-local-registry-#{driver}"
      else
        "kamal-local-#{driver}"
      end
    end
end
