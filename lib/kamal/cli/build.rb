require "uri"

class Kamal::Cli::Build < Kamal::Cli::Base
  class BuildError < StandardError; end

  desc "deliver", "Build app and push app image to registry then pull image on servers"
  def deliver
    mutating do
      push
      pull
    end
  end

  desc "push", "Build and push app image to registry"
  def push
    cli = self

    verify_local_dependencies
    run_hook "pre-build"

    if (uncommitted_changes = Kamal::Git.uncommitted_changes).present?
      say "The following paths have uncommitted changes:\n #{uncommitted_changes}", :yellow
    end

    run_locally do
      begin
        KAMAL.with_verbosity(:debug) do
          execute *KAMAL.builder.push
        end
      rescue SSHKit::Command::Failed => e
        if e.message =~ /(no builder)|(no such file or directory)/
          error "Missing compatible builder, so creating a new one first"

          if cli.create
            KAMAL.with_verbosity(:debug) { execute *KAMAL.builder.push }
          end
        else
          raise
        end
      end
    end
  end

  desc "pull", "Pull app image from registry onto servers"
  def pull
    mutating do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pulled image with version #{KAMAL.config.version}"), verbosity: :debug
        execute *KAMAL.builder.clean, raise_on_non_zero_exit: false
        execute *KAMAL.builder.pull
        execute *KAMAL.builder.validate_image
      end
    end
  end

  desc "create", "Create a build setup"
  def create
    mutating do
      if (remote_host = KAMAL.config.builder.remote_host)
        connect_to_remote_host(remote_host)
      end

      run_locally do
        begin
          debug "Using builder: #{KAMAL.builder.name}"
          execute *KAMAL.builder.create
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
    mutating do
      run_locally do
        debug "Using builder: #{KAMAL.builder.name}"
        execute *KAMAL.builder.remove
      end
    end
  end

  desc "details", "Show build setup"
  def details
    run_locally do
      puts "Builder: #{KAMAL.builder.name}"
      puts capture(*KAMAL.builder.info)
    end
  end

  private
    def verify_local_dependencies
      run_locally do
        begin
          execute *KAMAL.builder.ensure_local_dependencies_installed
        rescue SSHKit::Command::Failed => e
          build_error = e.message =~ /command not found/ ?
            "Docker is not installed locally" :
            "Docker buildx plugin is not installed locally"

          raise BuildError, build_error
        end
      end
    end

    def connect_to_remote_host(remote_host)
      remote_uri = URI.parse(remote_host)
      if remote_uri.scheme == "ssh"
        options = { user: remote_uri.user, port: remote_uri.port }.compact
        on(remote_uri.host, options) do
          execute "true"
        end
      end
    end
end
