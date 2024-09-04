class Kamal::Commands::Builder::Native::Pack < Kamal::Commands::Builder::Native
  def push
    combine \
      pack(:build,
        config.repository,
        "--platform", platform,
        "--builder", pack_builder,
        buildpacks,
        "-t", config.absolute_image,
        "-t", config.latest_image,
        "--env", "BP_IMAGE_LABELS=service=#{config.service}",
        secrets.map { |secret| [ "--env", Kamal::Utils.sensitive(ENV[secret]) ] },
        "--path", build_context),
      docker(:push, config.absolute_image),
      docker(:push, config.latest_image)
  end

  private
    def platform
      "linux/#{pack_arch}"
    end

    def buildpacks
      (pack_buildpacks << "paketo-buildpacks/image-labels").map { |buildpack| [ "--buildpack", buildpack ] }
    end
end
