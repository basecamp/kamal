require "mrsk/commands/base"

class Mrsk::Commands::Builder < Mrsk::Commands::Base
  delegate :create, :remove, :push, :pull, :info, to: :target
  delegate :native?, :multiarch?, :remote?, to: :name

  def name
    target.class.to_s.demodulize.downcase.inquiry
  end

  def target
    case
    when config.builder.nil?
      multiarch
    when config.builder["multiarch"] == false
      native
    when config.builder["local"] && config.builder["local"]
      multiarch_remote
    else
      raise ArgumentError, "Builder configuration incorrect: #{config.builder.inspect}"
    end
  end

  def native
    @native ||= Mrsk::Commands::Builder::Native.new(config)
  end

  def multiarch
    @multiarch ||= Mrsk::Commands::Builder::Multiarch.new(config)
  end

  def multiarch_remote
    @multiarch_remote ||= Mrsk::Commands::Builder::Multiarch::Remote.new(config)
  end
end

require "mrsk/commands/builder/native"
require "mrsk/commands/builder/multiarch"
require "mrsk/commands/builder/multiarch/remote"
