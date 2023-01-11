require_relative "setup"

PRUNE_IMAGES_AFTER     = 30.days.in_hours.to_i
PRUNE_CONTAINERS_AFTER =  3.days.in_hours.to_i

namespace :mrsk do
  desc "Prune unused images and stopped containers"
  task prune: %w[ prune:containers prune:images ]

  namespace :prune do
    desc "Prune unused images older than 30 days"
    task :images do
      on(MRSK_CONFIG.hosts) { execute "docker image prune -f --filter 'until=#{PRUNE_IMAGES_AFTER}h'" }
    end

    desc "Prune stopped containers for the service older than 3 days"
    task :containers do
      on(MRSK_CONFIG.hosts) { execute "docker container prune -f --filter label=service=#{MRSK_CONFIG.service} --filter 'until=#{PRUNE_CONTAINERS_AFTER}h'" }
    end
  end
end
