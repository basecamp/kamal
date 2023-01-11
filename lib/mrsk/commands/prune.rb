class Mrsk::Commands::Prune < Mrsk::Commands::Base
  PRUNE_IMAGES_AFTER     = 30.days.in_hours.to_i
  PRUNE_CONTAINERS_AFTER =  3.days.in_hours.to_i

  def images
    docker :image, :prune, "-f", "--filter", "until=#{PRUNE_IMAGES_AFTER}h"
  end

  def containers
    docker :image, :prune, "-f", "--filter", "until=#{PRUNE_IMAGES_AFTER}h"
    docker :container, :prune, "-f", "--filter", "label=service=#{config.service}", "--filter", "'until=#{PRUNE_CONTAINERS_AFTER}h'"
  end
end
