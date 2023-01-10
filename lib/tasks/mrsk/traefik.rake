require_relative "setup"

traefik = Mrsk::Commands::Traefik.new(MRSK_CONFIG)

namespace :mrsk do
  namespace :traefik do
    desc "Run Traefik on servers"
    task :run do
      on(MRSK_CONFIG.role(:web).hosts) { execute *traefik.run, raise_on_non_zero_exit: false }
    end

    desc "Start existing Traefik on servers"
    task :start do
      on(MRSK_CONFIG.role(:web).hosts) { execute *traefik.start, raise_on_non_zero_exit: false }
    end

    desc "Stop Traefik on servers"
    task :stop do
      on(MRSK_CONFIG.role(:web).hosts) { execute *traefik.stop, raise_on_non_zero_exit: false }
    end

    desc "Restart Traefik on servers"
    task restart: %i[ stop start ]

    desc "Display information about Traefik containers from servers"
    task :info do
      on(MRSK_CONFIG.role(:web).hosts) { |host| puts "Traefik Host: #{host}\n" + capture(*traefik.info) + "\n\n" }
    end

    desc "Remove Traefik container and image from servers"
    task remove: %i[ stop ] do
      on(MRSK_CONFIG.role(:web).hosts) do
        execute *traefik.remove_container
        execute *traefik.remove_image
      end
    end
  end
end
