class Mrsk::Cli::Build < Mrsk::Cli::Base
  class BuildError < StandardError; end

  desc "deliver", "Build app and push app image to registry then pull image on servers"
  def deliver
    with_lock do
      push
      pull
    end
  end

  desc "push", "Build and push app image to registry"
  def push
    with_lock do
      cli = self

      run_locally do
        begin
          if cli.verify_local_dependencies
            MRSK.with_verbosity(:debug) { execute *MRSK.builder.push }
          end
        rescue SSHKit::Command::Failed => e
          if e.message =~ /(no builder)|(no such file or directory)/
            error "Missing compatible builder, so creating a new one first"

            if cli.create
              MRSK.with_verbosity(:debug) { execute *MRSK.builder.push }
            end
          else
            raise
          end
        end
      end
    end
  end

  desc "pull", "Pull app image from registry onto servers"
  def pull
    with_lock do
      on(MRSK.hosts) do
        execute *MRSK.auditor.record("Pulled image with version #{MRSK.config.version}"), verbosity: :debug
        execute *MRSK.builder.clean, raise_on_non_zero_exit: false
        execute *MRSK.builder.pull
      end
    end
  end

  desc "create", "Create a build setup"
  def create
    with_lock do
      run_locally do
        begin
          debug "Using builder: #{MRSK.builder.name}"
          execute *MRSK.builder.create
        rescue SSHKit::Command::Failed => e
          if e.message =~ /stderr=(.*)/
            error "Couldn't create remote builder: #{$1}"
            false
          else
            raise
          end
        end
      end
    end
  end

  desc "remove", "Remove build setup"
  def remove
    with_lock do
      run_locally do
        debug "Using builder: #{MRSK.builder.name}"
        execute *MRSK.builder.remove
      end
    end
  end

  desc "details", "Show build setup"
  def details
    run_locally do
      puts "Builder: #{MRSK.builder.name}"
      puts capture(*MRSK.builder.info)
    end
  end


  desc "", "" # Really a private method, but needed to be invoked from #push
  def verify_local_dependencies
    run_locally do
      begin
        execute *MRSK.builder.ensure_local_dependencies_installed
      rescue SSHKit::Command::Failed => e
        build_error = e.message =~ /command not found/ ?
          "Docker is not installed locally" :
          "Docker buildx plugin is not installed locally"

        raise BuildError, build_error
      end
    end

    true
  end
end
