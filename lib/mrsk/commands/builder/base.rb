class Mrsk::Commands::Builder::Base < Mrsk::Commands::Base
  delegate :argumentize, to: Mrsk::Utils

  def clean
    docker :image, :rm, "--force", config.absolute_image
  end

  def pull
    docker :pull, config.absolute_image
  end

  def build_options
    [ *build_tags, *build_labels, *build_args, *build_secrets, *build_ssh, *build_dockerfile ]
  end

  def build_context
    context
  end

  private
    def build_tags
      [ "-t", config.absolute_image, "-t", config.latest_image ]
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

    def build_ssh
      argumentize "--ssh", ssh_args
    end

    def build_dockerfile
      argumentize "--file", dockerfile
    end

    def args
      (config.builder && config.builder["args"]) || {}
    end

    def ssh_args
      if config.builder && config.builder["ssh"]
        "default=#{config.builder["ssh"]}"
      else
        "default"
      end
    end

    def secrets
      (config.builder && config.builder["secrets"]) || []
    end

    def dockerfile
      (config.builder && config.builder["dockerfile"]) || "Dockerfile"
    end

    def context
      (config.builder && config.builder["context"]) || "."
    end
end
