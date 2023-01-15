require "mrsk/commands/base"

class Mrsk::Commands::Builder::Base < Mrsk::Commands::Base
  delegate :argumentize, to: Mrsk::Configuration

  def pull
    docker :pull, config.absolute_image
  end

  def build_args
    argumentize "--build-arg", args
  end

  private
    def args
      config.builder["args"] || {}
    end
end
