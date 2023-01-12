require "mrsk/commands/base"

class Mrsk::Commands::Builder < Mrsk::Commands::Base
  def create
    docker :buildx, :create, "--use", "--name", "mrsk"
  end

  def remove
    docker :buildx, :rm, "mrsk"
  end

  def push
    docker :buildx, :build, "--push", "--platform linux/amd64,linux/arm64", "-t", config.absolute_image, "."
  end

  def pull
    docker :pull, config.absolute_image
  end


  def create_context(arch, host)
    docker :context, :create, "mrsk-#{arch}", "--description", "'MRSK #{arch} Native Host'", "--docker", "'host=#{host}'"
  end

  def remove_context(arch)
    docker :context, :rm, "mrsk-#{arch}"
  end


  def create_with_context(arch)
    docker :buildx, :create, "--use", "--name", "mrsk", "mrsk-#{arch}"
  end

  def append_context(arch)
    docker :buildx, :create, "--append", "--name", "mrsk", "mrsk-#{arch}"
  end
end
