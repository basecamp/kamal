require "mrsk/commands/base"

class Mrsk::Commands::Builder::Base < Mrsk::Commands::Base
  delegate :argumentize, to: Mrsk::Configuration
  delegate :simple_secretize, to: Mrsk::Configuration

  def pull
    docker :pull, config.absolute_image
  end

  def build_args
    argumentize "--build-arg", args, redacted: true
  end

  def build_secrets
    simple_secretize "--secret", secrets, redacted: true
  end

  private
    def args
      config.builder["args"] || {}
    end

    def secrets
      config.builder["secrets"] || {}
    end
end
