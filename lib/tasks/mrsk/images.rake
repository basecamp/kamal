require_relative "setup"

namespace :mrsk do
  namespace :images do
    desc "Prune unused images older than 30 days"
    task :prune do
      on(MRSK_CONFIG.servers) { execute "docker image prune -f --filter 'until=720h'" }
    end
  end
end
