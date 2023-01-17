require "mrsk/cli/base"

class Mrsk::Cli::Build < Mrsk::Cli::Base
  desc "deliver", "Deliver a newly built app image to servers"
  def deliver
    invoke :push
    invoke :pull
  end

  desc "push", "Build locally and push app image to registry"
  def push
    run_locally do 
      begin
        debug "Using builder: #{MRSK.builder.name}"
        info "Building image may take a while (run with --verbose for progress logging)" unless options[:verbose]
        execute *MRSK.builder.push
      rescue SSHKit::Command::Failed => e
        error "Missing compatible builder, so creating a new one first"
        execute *MRSK.builder.create
        execute *MRSK.builder.push
      end
    end
  end

  desc "pull", "Pull app image from the registry onto servers"
  def pull
    on(MRSK.config.hosts) { execute *MRSK.builder.pull }
  end

  desc "create", "Create a local build setup"
  def create
    run_locally do
      debug "Using builder: #{MRSK.builder.name}"
      execute *MRSK.builder.create
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
      puts "Builder: #{MRSK.builder.name} (#{MRSK.builder.target.class.name})"
      puts capture(*MRSK.builder.info)
    end
  end
end
