require_relative "setup"

app = Mrsk::Commands::App.new(MRSK_CONFIG)

namespace :mrsk do
  namespace :app do
    desc "Build and push app image to servers"
    task :push do
      run_locally             { execute app.push }
      on(MRSK_CONFIG.servers) { execute app.pull }
    end

    desc "Start app on servers"
    task :start do
      on(MRSK_CONFIG.servers) { execute app.start }
    end

    desc "Stop app on servers"
    task :stop do
      on(MRSK_CONFIG.servers) { execute app.stop, raise_on_non_zero_exit: false }
    end

    desc "Restart app on servers"
    task restart: %i[ stop start ]

    desc "Display information about app containers"
    task :info do
      on(MRSK_CONFIG.servers) { |host| puts "Host: #{host}\n" + capture(app.info) + "\n\n" }
    end
  end
end
