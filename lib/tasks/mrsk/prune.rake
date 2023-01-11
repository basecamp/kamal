require_relative "setup"

prune = Mrsk::Commands::Prune.new(MRSK_CONFIG)

namespace :mrsk do
  desc "Prune unused images and stopped containers"
  task prune: %w[ prune:containers prune:images ]

  namespace :prune do
    desc "Prune unused images older than 30 days"
    task :images do
      on(MRSK_CONFIG.hosts) { execute *prune.images }
    end

    desc "Prune stopped containers for the service older than 3 days"
    task :containers do
      on(MRSK_CONFIG.hosts) { execute *prune.containers }
    end
  end
end
