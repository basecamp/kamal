require_relative "setup"

namespace :mrsk do
  namespace :builder do
    desc "Deliver a newly built app image to servers"
    task deliver: %i[ push pull ]

    desc "Build locally and push app image to registry"
    task :push do
      run_locally do 
        begin
          info "Building multi-architecture images may take a while (run with VERBOSE=1 for progress logging)"
          execute *MRSK.builder.push
        rescue SSHKit::Command::Failed => e
          error "Missing compatible buildx builder, so creating a new one first"
          execute *MRSK.builder.create
          execute *MRSK.builder.push
        end
      end unless ENV["VERSION"]
    end

    desc "Pull app image from the registry onto servers"
    task :pull do
      on(MRSK.config.hosts) { execute *MRSK.builder.pull }
    end
  end
end
