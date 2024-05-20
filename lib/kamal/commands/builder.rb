require "active_support/core_ext/string/filters"

class Kamal::Commands::Builder < Kamal::Commands::Base
  delegate :create, :remove, :push, :clean, :pull, :info, :validate_image, to: :target
  delegate :clone_directory, :build_directory, to: :"config.builder"

  def name
    target.class.to_s.remove("Kamal::Commands::Builder::").underscore.inquiry
  end

  def target
    case
    when !config.builder.multiarch? && !config.builder.cached?
      native
    when !config.builder.multiarch? && config.builder.cached?
      native_cached
    when config.builder.local? && config.builder.remote?
      multiarch_remote
    when config.builder.remote?
      native_remote
    else
      multiarch
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

  def create_clone_directory
    make_directory clone_directory
  end

  def clone
    git :clone, Kamal::Git.root, path: clone_directory
  end

  def clone_reset_steps
    [
      git(:remote, "set-url", :origin, Kamal::Git.root, path: build_directory),
      git(:fetch, :origin, path: build_directory),
      git(:reset, "--hard", Kamal::Git.revision, path: build_directory),
      git(:clean, "-fdx", path: build_directory)
    ]
  end

  private
    def ensure_local_docker_installed
      docker "--version"
    end

    def ensure_local_buildx_installed
      docker :buildx, "version"
    end
end
