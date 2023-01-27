require "mrsk/cli/base"

class Mrsk::Cli::Build < Mrsk::Cli::Base
  desc "deliver", "Deliver a newly built app image to servers"
  def deliver
    invoke :push
    invoke :pull
  end

  desc "push", "Build locally and push app image to registry"
  def push
    verbose = options[:verbose]
    cli = self

    run_locally do 
      begin
        MRSK.verbosity(:debug) { execute *MRSK.builder.push }
      rescue SSHKit::Command::Failed => e
        if e.message =~ /(no builder)|(no such file or directory)/
          error "Missing compatible builder, so creating a new one first"

          if cli.create
            MRSK.verbosity(:debug) { execute *MRSK.builder.push }
          end
        else
          raise
        end
      end
    end
  end

  desc "pull", "Pull app image from the registry onto servers"
  def pull
    on(MRSK.hosts) { execute *MRSK.builder.pull }
  end

  desc "create", "Create a local build setup"
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

  desc "remove", "Remove local build setup"
  def remove
    run_locally do
      debug "Using builder: #{MRSK.builder.name}"
      execute *MRSK.builder.remove
    end
  end

  desc "details", "Show the name of the configured builder"
  def details
    run_locally do
      puts "Builder: #{MRSK.builder.name}"
      puts capture(*MRSK.builder.info)
    end
  end
end
