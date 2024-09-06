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
end
