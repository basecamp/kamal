require_relative "setup"

namespace :mrsk do
  namespace :build do
    desc "Deliver a newly built app image to servers"
    task deliver: %i[ push pull ]

    desc "Build locally and push app image to registry"
    task :push do
      run_locally do 
        begin
          debug "Using builder: #{MRSK.builder.name}"
          info "Building images may take a while (run with VERBOSE=1 for progress logging)"
          execute *MRSK.builder.push
        rescue SSHKit::Command::Failed => e
          error "Missing compatible builder, so creating a new one first"
          execute *MRSK.builder.create
          execute *MRSK.builder.push
        end
      end unless ENV["VERSION"]
    end

    desc "Pull app image from the registry onto servers"
    task :pull do
      on(MRSK.config.hosts) { execute *MRSK.builder.pull }
    end

    desc "Create a local build setup"
    task :create do
      run_locally do
        debug "Using builder: #{MRSK.builder.name}"
        execute *MRSK.builder.create
      end
    end

    desc "Remove local build setup"
    task :remove do
      run_locally do
        debug "Using builder: #{MRSK.builder.name}"
        execute *MRSK.builder.remove
      end
    end
  end
end
