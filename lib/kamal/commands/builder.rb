require "active_support/core_ext/string/filters"

class Kamal::Commands::Builder < Kamal::Commands::Base
  delegate :create, :remove, :push, :clean, :pull, :info, :inspect_builder, :validate_image, :first_mirror, to: :target
  delegate :local?, :remote?, to: "config.builder"

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
