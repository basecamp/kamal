require "mrsk/commands/base"

class Mrsk::Commands::Builder < Mrsk::Commands::Base
  def create
    docker :buildx, :create, "--use", "--name", "mrsk"
  end

  def push
    docker :buildx, :build, "--push", "--platform linux/amd64,linux/arm64", "-t", config.absolute_image, "."
  end

  def pull
    docker :pull, config.absolute_image
  end
end
