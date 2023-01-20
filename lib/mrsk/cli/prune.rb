require "mrsk/cli/base"

class Mrsk::Cli::Prune < Mrsk::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    invoke :containers
    invoke :images
  end

  desc "images", "Prune unused images older than 30 days"
  def images
    on(MRSK.hosts) { execute *MRSK.prune.images }
  end

  desc "containers", "Prune stopped containers for the service older than 3 days"
  def containers
    on(MRSK.hosts) { execute *MRSK.prune.containers }
  end
end
