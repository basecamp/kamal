class Kamal::Commands::Builder::Pack < Kamal::Commands::Builder::Base
  def push(export_action = "registry")
    combine \
      build,
      export(export_action)
  end

  def remove;end

  def info
    pack :builder, :inspect, pack_builder
  end
  alias_method :inspect_builder, :info

  private
    def build
      pack(:build,
        config.repository,
        "--platform", platform,
        "--creation-time", "now",
        "--builder", pack_builder,
        buildpacks,
        "-t", config.absolute_image,
        "-t", config.latest_image,
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
