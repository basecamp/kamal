
class Kamal::Commands::Builder::Base < Kamal::Commands::Base
  class BuilderError < StandardError; end

  delegate :argumentize, to: Kamal::Utils
  delegate :args, :secrets, :dockerfile, :local_arch, :local_host, :remote_arch, :remote_host, :cache_from, :cache_to, :ssh, :git_archive?, to: :builder_config

  def clean
    docker :image, :rm, "--force", config.absolute_image
  end

  def pull
    docker :pull, config.absolute_image
  end

  def push
    if git_archive?
      pipe \
        git(:archive, "--format=tar", :HEAD),
        build_and_push
    else
      build_and_push
    end
  end

  def build_options
    [ *build_tags, *build_cache, *build_labels, *build_args, *build_secrets, *build_dockerfile, *build_ssh ]
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


  private
    def build_tags
      [ "-t", config.absolute_image, "-t", config.latest_image ]
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
      argumentize "--secret", secrets.collect { |secret| [ "id", secret ] }
    end

    def build_dockerfile
      if Pathname.new(File.expand_path(dockerfile)).exist?
        argumentize "--file", dockerfile
      else
        raise BuilderError, "Missing #{dockerfile}"
      end
    end

    def build_ssh
      argumentize "--ssh", ssh if ssh.present?
    end

    def builder_config
      config.builder
    end
end
