require "active_support/duration"
require "active_support/core_ext/numeric/time"

class Mrsk::Commands::Prune < Mrsk::Commands::Base
  def images(until_hours: 7.days.in_hours.to_i)
    docker :image, :prune, "--all", "--force", "--filter", "label=service=#{config.service}", "--filter", "until=#{until_hours}h"
  end

  def containers(until_hours: 3.days.in_hours.to_i)
    docker :container, :prune, "--force", "--filter", "label=service=#{config.service}", "--filter", "until=#{until_hours}h"
  end
end
