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
          execute *MRSK.builder.create
          execute *MRSK.builder.push
        end
      end unless ENV["VERSION"]
    end

    desc "Pull app image from the registry onto servers"
    task :pull do
      on(MRSK.config.hosts) { execute *MRSK.builder.pull }
    end

    desc "Create a local buildx setup to produce multi-arch images"
    task :create do
      run_locally do
        execute *MRSK.builder.create
      end
    end

    desc "Remove local buildx setup"
    task :remove do
      run_locally do
        execute *MRSK.builder.remove
      end
    end

    namespace :remote do
      desc "Create local and remote buildx setup for fully native multi-arch builds"
      task create: %w[ create:context create:buildx ]

      namespace :create do
        task :context do
          if MRSK.config.builder && 
              (local = MRSK.config.builder["local"]) &&
              (remote = MRSK.config.builder["remote"])
            run_locally do
              execute *MRSK.builder.create_context(local["arch"], local["host"])
              execute *MRSK.builder.create_context(remote["arch"], remote["host"])
            end
          else
            error "Missing configuration of builder:local/remote in config"
          end
        end

        task :buildx do
          if MRSK.config.builder && 
              (local = MRSK.config.builder["local"]) &&
              (remote = MRSK.config.builder["remote"])
            run_locally do
              execute *MRSK.builder.create_with_context(local["arch"])
              execute *MRSK.builder.append_context(remote["arch"])
            end
          else
            error "Missing configuration of builder:local/remote in config"
          end
        end
      end


      desc "Remove local and remote buildx setup"
      task remove: %w[ remove:context mrsk:build:remove ]

      namespace :remove do
        task :context do
          if MRSK.config.builder && 
              (local = MRSK.config.builder["local"]) &&
              (remote = MRSK.config.builder["remote"])
            run_locally do
              execute *MRSK.builder.remove_context(local["arch"])
              execute *MRSK.builder.remove_context(remote["arch"])
            end
          else
            error "Missing configuration of builder:local/remote in config"
          end
        end
      end
    end
  end
end
