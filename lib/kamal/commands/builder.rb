require "active_support/core_ext/string/filters"

class Kamal::Commands::Builder < Kamal::Commands::Base
  delegate :create, :remove, :dev, :push, :clean, :pull, :info, :inspect_builder, :validate_image, :first_mirror, to: :target
  delegate :local?, :remote?, :cloud?, to: "config.builder"

  include Clone

  def name
    target.class.to_s.remove("Kamal::Commands::Builder::").underscore.inquiry
  end

  def target
    if remote?
      if local?
        hybrid
      else
        remote
      end
    elsif cloud?
      cloud
    else
      local
    end
  end

  def remote
    @remote ||= Kamal::Commands::Builder::Remote.new(config)
  end

  def local
    @local ||= Kamal::Commands::Builder::Local.new(config)
  end

  def hybrid
    @hybrid ||= Kamal::Commands::Builder::Hybrid.new(config)
  end

  def cloud
    @cloud ||= Kamal::Commands::Builder::Cloud.new(config)
  end
end
