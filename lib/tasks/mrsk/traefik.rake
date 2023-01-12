require_relative "setup"

namespace :mrsk do
  namespace :traefik do
    desc "Run Traefik on servers"
    task :run do
      on(MRSK.config.role(:web).hosts) { execute *MRSK.traefik.run, raise_on_non_zero_exit: false }
    end

    desc "Start existing Traefik on servers"
    task :start do
      on(MRSK.config.role(:web).hosts) { execute *MRSK.traefik.start, raise_on_non_zero_exit: false }
    end

    desc "Stop Traefik on servers"
    task :stop do
      on(MRSK.config.role(:web).hosts) { execute *MRSK.traefik.stop, raise_on_non_zero_exit: false }
    end

    desc "Restart Traefik on servers"
    task restart: %i[ stop start ]

    desc "Display information about Traefik containers from servers"
    task :info do
      on(MRSK.config.role(:web).hosts) { |host| puts "Traefik Host: #{host}\n" + capture(*MRSK.traefik.info) + "\n\n" }
    end

    desc "Show last 100 log lines from Traefik on servers"
    task :logs do
      on(MRSK.config.hosts) { |host| puts "Traefik Host: #{host}\n" + capture(*MRSK.traefik.logs) + "\n\n" }
    end

    desc "Remove Traefik container and image from servers"
    task remove: %i[ stop ] do
      on(MRSK.config.role(:web).hosts) do
        execute *MRSK.traefik.remove_container
        execute *MRSK.traefik.remove_image
      end
    end
  end
end
