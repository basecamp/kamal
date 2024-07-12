require "uri"

class Kamal::Cli::Build < Kamal::Cli::Base
  class BuildError < StandardError; end

  desc "deliver", "Build app and push app image to registry then pull image on servers"
  def deliver
    push
    pull
  end

  desc "push", "Build and push app image to registry"
  def push
    cli = self

    verify_local_dependencies
    run_hook "pre-build"

    uncommitted_changes = Kamal::Git.uncommitted_changes

    if KAMAL.config.builder.git_clone?
      if uncommitted_changes.present?
        say "Building from a local git clone, so ignoring these uncommitted changes:\n #{uncommitted_changes}", :yellow
      end

      run_locally do
        Clone.new(self).prepare
      end
    elsif uncommitted_changes.present?
      say "Building with uncommitted changes:\n #{uncommitted_changes}", :yellow
    end

    # Get the command here to ensure the Dir.chdir doesn't interfere with it
    push = KAMAL.builder.push

    run_locally do
      begin
        context_hosts = capture_with_info(*KAMAL.builder.context_hosts).split("\n")

        if context_hosts != KAMAL.builder.config_context_hosts
          warn "Context hosts have changed, so re-creating builder, was: #{context_hosts.join(", ")}], now: #{KAMAL.builder.config_context_hosts.join(", ")}"
          cli.remove
          cli.create
        end
      rescue SSHKit::Command::Failed => e
        if e.message =~ /(context not found|no builder|does not exist)/
          warn "Missing compatible builder, so creating a new one first"
          cli.create
        else
          raise
        end
      end

      KAMAL.with_verbosity(:debug) do
        Dir.chdir(KAMAL.config.builder.build_directory) { execute *push }
      end
    end
  end

  desc "pull", "Pull app image from registry onto servers"
  def pull
    on(KAMAL.hosts) do
      execute *KAMAL.auditor.record("Pulled image with version #{KAMAL.config.version}"), verbosity: :debug
      execute *KAMAL.builder.clean, raise_on_non_zero_exit: false
      execute *KAMAL.builder.pull
      execute *KAMAL.builder.validate_image
    end
  end

  desc "create", "Create a build setup"
  def create
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

  desc "remove", "Remove build setup"
  def remove
    run_locally do
      debug "Using builder: #{KAMAL.builder.name}"
      execute *KAMAL.builder.remove
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
        host = SSHKit::Host.new(
          hostname: remote_uri.host,
          ssh_options: { user: remote_uri.user, port: remote_uri.port }.compact
        )
        on(host, options) do
          execute "true"
        end
      end
    end
end
