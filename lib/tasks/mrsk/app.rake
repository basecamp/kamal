require_relative "setup"

app = Mrsk::Commands::App.new(MRSK_CONFIG)

namespace :mrsk do
  namespace :app do
    desc "Deliver a newly built app image to servers"
    task deliver: %i[ push pull ]

    desc "Build locally and push app image to registry"
    task :push do
      run_locally { execute *app.push } unless ENV["VERSION"]
    end

    desc "Pull app image from the registry onto servers"
    task :pull do
      on(MRSK_CONFIG.hosts) { execute *app.pull }
    end

    desc "Run app on servers (or start them if they've already been run)"
    task :run do
      MRSK_CONFIG.roles.each do |role|
        on(role.hosts) do |host|
          begin
            execute *app.run(role: role.name)
          rescue SSHKit::Command::Failed => e
            if e.message =~ /already in use/
              error "Container with same version already deployed on #{host}, starting that instead"
              execute *app.start, host: host
            else
              raise
            end
          end
        end
      end
    end

    desc "Start existing app on servers (use VERSION=<git-hash> to designate which version)"
    task :start do
      on(MRSK_CONFIG.hosts) { execute *app.start, raise_on_non_zero_exit: false }
    end

    desc "Stop app on servers"
    task :stop do
      on(MRSK_CONFIG.hosts) { execute *app.stop, raise_on_non_zero_exit: false }
    end

    desc "Start app on servers (use VERSION=<git-hash> to designate which version)"
    task restart: %i[ stop start ]

    desc "Display information about app containers"
    task :info do
      on(MRSK_CONFIG.hosts) { |host| puts "App Host: #{host}\n" + capture(*app.info) + "\n\n" }
    end

    desc "Execute a custom task on servers passed in as CMD='bin/rake some:task'"
    task :exec do
      on(MRSK_CONFIG.hosts) { |host| puts "App Host: #{host}\n" + capture(*app.exec(ENV["CMD"])) + "\n\n" }
    end

    desc "Start Rails Console on primary host"
    task :console do
      puts "Launching Rails console on #{MRSK_CONFIG.primary_host}..."
      exec app.console
    end

    namespace :exec do
      desc "Execute Rails command on servers, like CMD='runner \"puts %(Hello World)\""
      task :rails do
        on(MRSK_CONFIG.hosts) { |host| puts "App Host: #{host}\n" + capture(*app.exec("bin/rails", ENV["CMD"])) + "\n\n" }
      end

      desc "Execute a custom task on the first defined server"
      task :once do
        on(MRSK_CONFIG.primary_host) { puts capture(*app.exec(ENV["CMD"])) }
      end

      namespace :once do
        desc "Execute Rails command on the first defined server, like CMD='runner \"puts %(Hello World)\""
        task :rails do
          on(MRSK_CONFIG.primary_host) { puts capture(*app.exec("bin/rails", ENV["CMD"])) }
        end
      end
    end

    desc "List all the app containers currently on servers"
    task :containers do
      on(MRSK_CONFIG.hosts) { |host| puts "App Host: #{host}\n" + capture(*app.list_containers) + "\n\n" }
    end

    desc "Tail logs from app containers"
    task :logs do
      on(MRSK_CONFIG.hosts) { execute *app.logs }
    end

    desc "Remove app containers and images from servers"
    task remove: %i[ stop ] do
      on(MRSK_CONFIG.hosts) do
        execute *app.remove_containers
        execute *app.remove_images
      end
    end
  end
end
