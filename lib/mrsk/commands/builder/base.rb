
class Mrsk::Commands::Builder::Base < Mrsk::Commands::Base
  class BuilderError < StandardError; end

  delegate :argumentize, to: Mrsk::Utils

  def clean
    docker :image, :rm, "--force", config.absolute_image
  end

  def pull
    docker :pull, config.absolute_image
  end

  def build_options
    [ *build_tags, *build_cache, *build_labels, *build_args, *build_secrets, *build_dockerfile ]
  end

  def build_context
    config.builder.context
  end


  private
    def build_tags
      [ "-t", config.absolute_image, "-t", config.latest_image ]
    end

    def build_cache
      if config.builder.cache?
        ["--cache-to", config.builder.cache_to,
          "--cache-from", config.builder.cache_from]
      end
    end

    def build_labels
      argumentize "--label", { service: config.service }
    end

    def build_args
      argumentize "--build-arg", config.builder.args, sensitive: true
    end

    def build_secrets
      argumentize "--secret", config.builder.secrets.collect { |secret| [ "id", secret ] }
    end

    def build_dockerfile
      if Pathname.new(File.expand_path(config.builder.dockerfile)).exist?
        argumentize "--file", config.builder.dockerfile
      else
        raise BuilderError, "Missing #{config.builder.dockerfile}"
      end
    end
end
