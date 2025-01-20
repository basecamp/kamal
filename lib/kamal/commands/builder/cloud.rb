class Kamal::Commands::Builder::Cloud < Kamal::Commands::Builder::Base
  # Expects `driver` to be of format "cloud docker-org-name/builder-name"

  def create
    docker :buildx, :create, "--driver", driver
  end

  def remove
    docker :buildx, :rm, builder_name
  end

  private
    def builder_name
      driver.gsub(/[ \/]/, "-")
    end

    def inspect_buildx
      pipe \
        docker(:buildx, :inspect, builder_name),
        grep("-q", "Endpoint:.*cloud://.*")
    end
end
