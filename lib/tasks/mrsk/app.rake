require_relative "setup"

namespace :mrsk do
  namespace :app do
    desc "Run app on servers (or start them if they've already been run)"
    task :run do
      MRSK.config.roles.each do |role|
        on(role.hosts) do |host|
          begin
            execute *MRSK.app.run(role: role.name)
          rescue SSHKit::Command::Failed => e
            if e.message =~ /already in use/
              error "Container with same version already deployed on #{host}, starting that instead"
              execute *MRSK.app.start, host: host
            else
              raise
            end
          end
        end
      end
    end

    desc "Start existing app on servers (use VERSION=<git-hash> to designate which version)"
    task :start do
      on(MRSK.config.hosts) { execute *MRSK.app.start, raise_on_non_zero_exit: false }
    end

    desc "Stop app on servers"
    task :stop do
      on(MRSK.config.hosts) { execute *MRSK.app.stop, raise_on_non_zero_exit: false }
    end

    desc "Start app on servers (use VERSION=<git-hash> to designate which version)"
    task restart: %i[ stop start ]

    desc "Display information about app containers"
    task :info do
      on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.info) + "\n\n" }
    end

    desc "Execute a custom task on servers passed in as CMD='bin/rake some:task'"
    task :exec do
      on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.exec(ENV["CMD"])) + "\n\n" }
    end

    desc "Start Rails Console on primary host"
    task :console do
      puts "Launching Rails console on #{MRSK.config.primary_host}..."
      exec app.console
    end

    namespace :exec do
      desc "Execute Rails command on servers, like CMD='runner \"puts %(Hello World)\""
      task :rails do
        on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.exec("bin/rails", ENV["CMD"])) + "\n\n" }
      end

      desc "Execute a custom task on the first defined server"
      task :once do
        on(MRSK.config.primary_host) { puts capture(*MRSK.app.exec(ENV["CMD"])) }
      end

      namespace :once do
        desc "Execute Rails command on the first defined server, like CMD='runner \"puts %(Hello World)\""
        task :rails do
          on(MRSK.config.primary_host) { puts capture(*MRSK.app.exec("bin/rails", ENV["CMD"])) }
        end
      end
    end

    desc "List all the app containers currently on servers"
    task :containers do
      on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.list_containers) + "\n\n" }
    end

    desc "Show last 100 log lines from app on servers"
    task :logs do
      # FIXME: Catch when app containers aren't running
      on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.logs) + "\n\n" }
    end

    desc "Remove app containers and images from servers"
    task remove: %w[ remove:containers remove:images ]

    namespace :remove do
      desc "Remove app containers from servers"
      task :containers do
        on(MRSK.config.hosts) { execute *MRSK.app.remove_containers }
      end
      
      desc "Remove app images from servers"
      task :images do
        on(MRSK.config.hosts) { execute *MRSK.app.remove_images }
      end
    end
  end
end
