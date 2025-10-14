class Kamal::Commands::Builder::Pack < Kamal::Commands::Builder::Base
  def push(export_action = "registry", tag_as_dirty: false, no_cache: false)
    combine \
      build(tag_as_dirty: tag_as_dirty, no_cache: no_cache),
      export(export_action)
  end

  def remove;end

  def info
    pack :builder, :inspect, pack_builder
  end
  alias_method :inspect_builder, :info

  private
    def build(tag_as_dirty: false, no_cache: false)
      pack(:build,
        config.repository,
        "--platform", platform,
        "--creation-time", "now",
        "--builder", pack_builder,
        buildpacks,
        *build_tag_options(tag_as_dirty: tag_as_dirty),
        *([ "--clear-cache" ] if no_cache),
        "--env", "BP_IMAGE_LABELS=service=#{config.service}",
        *argumentize("--env", args),
        *argumentize("--env", secrets, sensitive: true),
        "--path", build_context)
    end

    def export(export_action)
      return unless export_action == "registry"

      combine \
        docker(:push, config.absolute_image),
        docker(:push, config.latest_image)
    end

    def platform
      "linux/#{local_arches.first}"
    end

    def buildpacks
      (pack_buildpacks << "paketo-buildpacks/image-labels").map { |buildpack| [ "--buildpack", buildpack ] }
    end
end
