require "mrsk/commands/builder/multiarch"

class Mrsk::Commands::Builder::Multiarch::Remote < Mrsk::Commands::Builder::Multiarch
  def create(arch)
    super + [ "mrsk-#{arch}", "--platform", "linux/#{arch}" ]
  end

  def append(arch)
    docker :buildx, :create, "--append", "--name", "mrsk", "mrsk-#{arch}", "--platform", "linux/#{arch}"
  end

  def create_context(arch, host)
    docker :context, :create, "mrsk-#{arch}", "--description", "'MRSK #{arch} Native Host'", "--docker", "'host=#{host}'"
  end

  def remove_context(arch)
    docker :context, :rm, "mrsk-#{arch}"
  end
end
