require "mrsk/commands/base"

class Mrsk::Commands::Builder::Base < Mrsk::Commands::Base
  delegate :argumentize, :secretize, to: Mrsk::Configuration

  def pull
    docker :pull, config.absolute_image
  end

  def build_args
    argumentize "--build-arg", args, redacted: true
  end

  def build_secrets
    secretize "--secret", secrets
  end

  private
    def args
      config.builder["args"] || {}
    end

    def secrets
      config.builder["secrets"] || {}
    end
end
