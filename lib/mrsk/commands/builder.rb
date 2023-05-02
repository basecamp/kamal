class Mrsk::Commands::Builder < Mrsk::Commands::Base
  delegate :create, :remove, :push, :clean, :pull, :info, to: :target

  def name
    target.class.to_s.remove("Mrsk::Commands::Builder::").underscore.inquiry
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


  def ensure_local_dependencies_installed
    if name.native?
      ensure_local_docker_installed
    else
      combine \
        ensure_local_docker_installed,
        ensure_local_buildx_installed
    end
  end

  private
    def ensure_local_docker_installed
      docker "--version"
    end

    def ensure_local_buildx_installed
      docker :buildx, "version"
    end
end
