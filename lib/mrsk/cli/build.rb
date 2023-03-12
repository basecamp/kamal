class Mrsk::Cli::Build < Mrsk::Cli::Base
  desc "deliver", "Build app and push app image to registry then pull image on servers"
  def deliver
    push unless MRSK.use_prebuilt_image
    pull
  end

  desc "push", "Build and push app image to registry"
  def push
    cli = self

    run_locally do
      begin
        MRSK.with_verbosity(:debug) { execute *MRSK.builder.push }
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

  desc "pull", "Pull app image from registry onto servers"
  def pull
    on(MRSK.hosts) do
      execute *MRSK.auditor.record("Pulled image with version #{MRSK.version}"), verbosity: :debug
      execute *MRSK.builder.clean, raise_on_non_zero_exit: false
      execute *MRSK.builder.pull
    end
  end

  desc "create", "Create a build setup"
  def create
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

  desc "remove", "Remove build setup"
  def remove
    run_locally do
      debug "Using builder: #{MRSK.builder.name}"
      execute *MRSK.builder.remove
    end
  end

  desc "details", "Show build setup"
  def details
    run_locally do
      puts "Builder: #{MRSK.builder.name}"
      puts capture(*MRSK.builder.info)
    end
  end
end
