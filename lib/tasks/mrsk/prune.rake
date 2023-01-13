require_relative "setup"

namespace :mrsk do
  desc "Prune unused images and stopped containers"
  task prune: %w[ prune:containers prune:images ]

  namespace :prune do
    desc "Prune unused images older than 30 days"
    task :images do
      on(MRSK.config.hosts) { execute *MRSK.prune.images }
    end

    desc "Prune stopped containers for the service older than 3 days"
    task :containers do
      on(MRSK.config.hosts) { execute *MRSK.prune.containers }
    end
  end
end
