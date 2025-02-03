class Kamal::Commands::Builder::Base < Kamal::Commands::Base
  class BuilderError < StandardError; end

  ENDPOINT_DOCKER_HOST_INSPECT = "'{{.Endpoints.docker.Host}}'"

  delegate :argumentize, to: Kamal::Utils
  delegate \
    :args, :secrets, :dockerfile, :target, :arches, :local_arches, :remote_arches, :remote,
    :cache_from, :cache_to, :ssh, :provenance, :sbom, :driver, :docker_driver?,
    to: :builder_config

  def clean
    docker :image, :rm, "--force", config.absolute_image
  end

  def push(export_action = "registry", tag_as_dirty: false)
    docker :buildx, :build,
      "--output=type=#{export_action}",
      *platform_options(arches),
      *([ "--builder", builder_name ] unless docker_driver?),
      *build_tag_options(tag_as_dirty: tag_as_dirty),
      *build_options,
      build_context
  end

  def pull
    docker :pull, config.absolute_image
  end

  def info
    combine \
      docker(:context, :ls),
      docker(:buildx, :ls)
  end

  def inspect_builder
    docker :buildx, :inspect, builder_name unless docker_driver?
  end

  def build_options
    [ *build_cache, *build_labels, *build_args, *build_secrets, *build_dockerfile, *build_target, *build_ssh, *builder_provenance, *builder_sbom ]
  end

  def build_context
    config.builder.context
  end

  def validate_image
    pipe \
      docker(:inspect, "-f", "'{{ .Config.Labels.service }}'", config.absolute_image),
      any(
        [ :grep, "-x", config.service ],
        "(echo \"Image #{config.absolute_image} is missing the 'service' label\" && exit 1)"
      )
  end

  def first_mirror
    docker(:info, "--format '{{index .RegistryConfig.Mirrors 0}}'")
  end

  private
    def build_tag_names(tag_as_dirty: false)
      tag_names = [ config.absolute_image, config.latest_image ]
      tag_names.map! { |t| "#{t}-dirty" } if tag_as_dirty
      tag_names
    end

    def build_tag_options(tag_as_dirty: false)
      build_tag_names(tag_as_dirty: tag_as_dirty).flat_map { |name| [ "-t", name ] }
    end

    def build_cache
      if cache_to && cache_from
        [ "--cache-to", cache_to,
          "--cache-from", cache_from ]
      end
    end

    def build_labels
      argumentize "--label", { service: config.service }
    end

    def build_args
      argumentize "--build-arg", args, sensitive: true
    end

    def build_secrets
      argumentize "--secret", secrets.keys.collect { |secret| [ "id", secret ] }
    end

    def build_dockerfile
      if Pathname.new(File.expand_path(dockerfile)).exist?
        argumentize "--file", dockerfile
      else
        raise BuilderError, "Missing #{dockerfile}"
      end
    end

    def build_target
      argumentize "--target", target if target.present?
    end

    def build_ssh
      argumentize "--ssh", ssh if ssh.present?
    end

    def builder_provenance
      argumentize "--provenance", provenance unless provenance.nil?
    end

    def builder_sbom
      argumentize "--sbom", sbom unless sbom.nil?
    end

    def builder_config
      config.builder
    end

    def platform_options(arches)
      argumentize "--platform", arches.map { |arch| "linux/#{arch}" }.join(",") if arches.any?
    end
end
