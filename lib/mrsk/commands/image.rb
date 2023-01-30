require "mrsk/commands/base"
require "active_support/duration"
require "active_support/core_ext/numeric/time"

class Mrsk::Commands::Image < Mrsk::Commands::Base
  def list(format = nil)
    docker :images, config.repository, format ? "--format=#{format.to_s}" : ''
  end

  def rm(image_ids)
    docker :rmi, image_ids.join(' ')
  end
end
