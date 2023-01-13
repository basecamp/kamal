require_relative "setup"

namespace :mrsk do
  namespace :build do
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
          Rake::Task["mrsk:build:create"].invoke
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
        if MRSK.builder.remote?
          Rake::Task["mrsk:build:remote:create"].invoke
        else
          execute *MRSK.builder.create
        end
      end
    end

    desc "Remove local build setup"
    task :remove do
      run_locally do
        if MRSK.builder.remote?
          Rake::Task["mrsk:build:remote:create"].invoke
        else
          execute *MRSK.builder.remove
        end
      end
    end

    namespace :remote do
      desc "Create local and remote buildx setup for fully native multi-arch builds"
      task create: %w[ create:context create:buildx ]

      namespace :create do
        task :context do
          run_locally do
            execute *MRSK.builder.create_context(local["arch"], local["host"])
            execute *MRSK.builder.create_context(remote["arch"], remote["host"])
          end
        end

        task :buildx do
          run_locally do
            execute *MRSK.builder.create_with_context(local["arch"])
            execute *MRSK.builder.append_context(remote["arch"])
          end
        end
      end


      desc "Remove local and remote buildx setup"
      task remove: %w[ remove:context mrsk:build:remove ]

      namespace :remove do
        task :context do
          run_locally do
            execute *MRSK.builder.remove_context(local["arch"])
            execute *MRSK.builder.remove_context(remote["arch"])
          end
        end
      end
    end
  end
end
