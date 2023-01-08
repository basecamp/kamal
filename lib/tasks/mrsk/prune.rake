require_relative "setup"

namespace :mrsk do
  desc "Prune unused images and stopped containers"
  task prune: [ "prune:images", "prune:containers" ]

  namespace :prune do
    desc "Prune unused images older than 30 days"
    task :images do
      on(MRSK_CONFIG.servers) { execute "docker image prune -f --filter 'until=720h'" }
    end

    desc "Prune stopped containers for the service older than 3 days"
    task :containers do
      on(MRSK_CONFIG.servers) { execute "docker container prune -f --filter label=service=#{MRSK_CONFIG.service} --filter 'until=72h'" }
    end
  end
end
