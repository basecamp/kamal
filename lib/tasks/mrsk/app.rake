require_relative "setup"

app = Mrsk::Commands::App.new(MRSK_CONFIG)

namespace :mrsk do
  namespace :app do
    desc "Deliver a newly built app image to the servers"
    task deliver: %i[ push pull ]

    desc "Build locally and push app image to the registry"
    task :push do
      run_locally { execute app.push } unless ENV["SKIP_PUSH"]
    end

    desc "Pull app image from the registry onto servers"
    task :pull do
      on(MRSK_CONFIG.servers) { execute app.pull }
    end

    desc "Run app on servers"
    task :run do
      on(MRSK_CONFIG.servers) { execute app.run }
    end

    desc "Start existing app on servers"
    task :start do
      on(MRSK_CONFIG.servers) { execute app.start }
    end

    desc "Stop app on servers"
    task :stop do
      on(MRSK_CONFIG.servers) { execute app.stop, raise_on_non_zero_exit: false }
    end

    desc "Start app on servers (use VERSION=<git-hash> to designate which version)"
    task restart: %i[ stop start ]

    desc "Display information about app containers"
    task :info do
      on(MRSK_CONFIG.servers) { |host| puts "App Host: #{host}\n" + capture(app.info) + "\n\n" }
    end

    desc "Remove app containers and images from servers"
    task remove: %i[ stop ] do
      on(MRSK_CONFIG.servers) do
        execute app.remove_containers
        execute app.remove_images
      end
    end
  end
end
