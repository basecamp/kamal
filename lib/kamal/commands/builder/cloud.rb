class Kamal::Commands::Builder::Cloud < Kamal::Commands::Builder::Base
  # Expects `driver` to be of format "cloud docker-org-name/builder-name"

  def create
    docker :buildx, :create, "--driver", driver
  end

  def remove
    docker :buildx, :rm, builder_name
  end

  # Docker Build Cloud's cache is shared by the whole organization, so leave it alone
  def prune(max_used_space: nil);end

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
