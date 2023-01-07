require_relative "setup"

traefik = Mrsk::Commands::Traefik.new

namespace :mrsk do
  namespace :traefik do
    desc "Start Traefik"
    task :start do
      on(MRSK_CONFIG.servers) { execute traefik.start, raise_on_non_zero_exit: false }
    end

    desc "Stop Traefik"
    task :stop do
      on(MRSK_CONFIG.servers) { execute traefik.stop, raise_on_non_zero_exit: false }
    end

    desc "Restart Traefik"
    task restart: %i[ stop start ]

    desc "Display information about Traefik containers"
    task :info do
      on(MRSK_CONFIG.servers) { |host| puts "Host: #{host}\n" + capture(traefik.info) + "\n\n" }
    end
  end
end
