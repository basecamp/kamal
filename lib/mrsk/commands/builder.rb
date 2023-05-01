class Mrsk::Commands::Builder < Mrsk::Commands::Base
  delegate :create, :remove, :push, :clean, :pull, :info, to: :target

  def name
    target.class.to_s.remove("Mrsk::Commands::Builder::").underscore
  end

  def target
    case
    when config.builder && config.builder["multiarch"] == false
      native
    when config.builder && config.builder["local"] && config.builder["remote"]
      multiarch_remote
    when config.builder && config.builder["remote"]
      native_remote
    else
      multiarch
    end
  end

  def native
    @native ||= Mrsk::Commands::Builder::Native.new(config)
  end

  def native_remote
    @native ||= Mrsk::Commands::Builder::Native::Remote.new(config)
  end

  def multiarch
    @multiarch ||= Mrsk::Commands::Builder::Multiarch.new(config)
  end

  def multiarch_remote
    @multiarch_remote ||= Mrsk::Commands::Builder::Multiarch::Remote.new(config)
  end

  def native_and_local?
    name == 'native'
  end

  def dependencies
    if native_and_local?
      docker_version
    else
    combine \
      docker_version,
      docker_buildx_version
    end
  end

  private

    def docker_version
      docker "--version"
    end

    def docker_buildx_version
      docker :buildx, "version"
    end
end
