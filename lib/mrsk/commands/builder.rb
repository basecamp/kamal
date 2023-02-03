class Mrsk::Commands::Builder < Mrsk::Commands::Base
  delegate :create, :remove, :push, :pull, :info, to: :target

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
end
