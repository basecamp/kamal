require "active_support/core_ext/string/filters"

class Kamal::Commands::Builder < Kamal::Commands::Base
  delegate :create, :remove, :push, :clean, :pull, :info, :context_hosts, :config_context_hosts, :validate_image,
    to: :target

  include Clone

  def name
    target.class.to_s.remove("Kamal::Commands::Builder::").underscore.inquiry
  end

  def target
    if config.builder.multiarch?
      if config.builder.remote?
        if config.builder.local?
          multiarch_remote
        else
          native_remote
        end
      else
        multiarch
      end
    else
      if config.builder.cached?
        native_cached
      else
        native
      end
    end
  end

  def native
    @native ||= Kamal::Commands::Builder::Native.new(config)
  end

  def native_cached
    @native ||= Kamal::Commands::Builder::Native::Cached.new(config)
  end

  def native_remote
    @native ||= Kamal::Commands::Builder::Native::Remote.new(config)
  end

  def multiarch
    @multiarch ||= Kamal::Commands::Builder::Multiarch.new(config)
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
