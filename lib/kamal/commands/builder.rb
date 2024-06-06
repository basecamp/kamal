require "active_support/core_ext/string/filters"

class Kamal::Commands::Builder < Kamal::Commands::Base
  delegate :create, :remove, :push, :clean, :pull, :info, :context_hosts, :config_context_hosts, :validate_image,
           :first_mirror, to: :target

  include Clone

  def name
    target.class.to_s.remove("Kamal::Commands::Builder::").underscore.inquiry
  end

  def target
    case
    when !config.builder.multiarch? && !config.builder.cached?
      native
    when !config.builder.multiarch? && config.builder.cached?
      local
    when config.builder.local? && config.builder.remote?
      multiarch_remote
    when config.builder.remote?
      remote
    else
      local
    end
  end

  def native
    @native ||= Kamal::Commands::Builder::Native.new(config)
  end

  def remote
    @remote ||= Kamal::Commands::Builder::Remote.new(config)
  end

  def local
    @local ||= Kamal::Commands::Builder::Local.new(config)
  end

  def multiarch_remote
    @multiarch_remote ||= Kamal::Commands::Builder::Multiarch::Remote.new(config)
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
