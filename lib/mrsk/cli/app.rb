require "mrsk/cli/base"

class Mrsk::Cli::App < Mrsk::Cli::Base
  desc "boot", "Boot app on servers (or reboot app if already running)"
  def boot
    cli = self

    say "Ensure no other version of the app is running...", :magenta
    stop

    say "Get most recent version available as an image...", :magenta unless options[:version]
    using_version(options[:version] || most_recent_version_available) do |version|
      say "Start container with version #{version} (or reboot if already running)...", :magenta

      MRSK.config.roles.each do |role|
        on(role.hosts) do |host|
          execute *MRSK.auditor.record("app boot version #{version}"), verbosity: :debug

          begin
            execute *MRSK.app.run(role: role.name)
          rescue SSHKit::Command::Failed => e
            if e.message =~ /already in use/
              error "Rebooting container with same version already deployed on #{host}"

              cli.remove_container version
              execute *MRSK.app.run(role: role.name)
            else
              raise
            end
          end
        end
      end
    end
  end

  desc "start", "Start existing app on servers (use --version=<git-hash> to designate specific version)"
  def start
    on(MRSK.hosts) do
      execute *MRSK.auditor.record("app start version #{MRSK.version}"), verbosity: :debug
      execute *MRSK.app.start, raise_on_non_zero_exit: false
    end
  end
  
  desc "stop", "Stop app on servers"
  def stop
    on(MRSK.hosts) do
      execute *MRSK.auditor.record("app stop"), verbosity: :debug
      execute *MRSK.app.stop, raise_on_non_zero_exit: false
    end
  end
  
  desc "details", "Display details about app containers"
  def details
    on(MRSK.hosts) { |host| puts_by_host host, capture_with_info(*MRSK.app.info) }
  end
  
  desc "exec [CMD]", "Execute a custom command on servers"
  option :interactive, aliases: "-i", type: :boolean, default: false, desc: "Execute command over ssh for an interactive shell (use for console/bash)"
  option :reuse, type: :boolean, default: false, desc: "Reuse currently running container instead of starting a new one"
  def exec(cmd)
    case
    when options[:interactive] && options[:reuse]
      say "Get current version of running container...", :magenta unless options[:version]
      using_version(options[:version] || current_running_version) do |version|
        say "Launching interactive command with version #{version} via SSH from existing container on #{MRSK.primary_host}...", :magenta
        run_locally { exec MRSK.app.execute_in_existing_container_over_ssh(cmd, host: MRSK.primary_host) }
      end

    when options[:interactive]
      say "Get most recent version available as an image...", :magenta unless options[:version]
      using_version(options[:version] || most_recent_version_available) do |version|
        say "Launching interactive command with version #{version} via SSH from new container on #{MRSK.primary_host}...", :magenta
        run_locally { exec MRSK.app.execute_in_new_container_over_ssh(cmd, host: MRSK.primary_host) }
      end

    when options[:reuse]
      say "Get current version of running container...", :magenta unless options[:version]
      using_version(options[:version] || current_running_version) do |version|
        say "Launching command with version #{version} from existing container...", :magenta

        on(MRSK.hosts) do |host|
          execute *MRSK.auditor.record("app cmd '#{cmd}' with version #{version}"), verbosity: :debug
          puts_by_host host, capture_with_info(*MRSK.app.execute_in_existing_container(cmd))
        end
      end

    else
      say "Get most recent version available as an image...", :magenta unless options[:version]
      using_version(options[:version] || most_recent_version_available) do |version|
        say "Launching command with version #{version} from new container...", :magenta
        on(MRSK.hosts) do |host|
          execute *MRSK.auditor.record("app cmd '#{cmd}' with version #{version}"), verbosity: :debug
          puts_by_host host, capture_with_info(*MRSK.app.execute_in_new_container(cmd))
        end
      end
    end
  end

  desc "containers", "List all the app containers currently on servers"
  def containers
    on(MRSK.hosts) { |host| puts_by_host host, capture_with_info(*MRSK.app.list_containers) }
  end

  desc "images", "List all the app images currently on servers"
  def images
    on(MRSK.hosts) { |host| puts_by_host host, capture_with_info(*MRSK.app.list_images) }
  end

  desc "current", "Return the current running container ID"
  def current
    on(MRSK.hosts) { |host| puts_by_host host, capture_with_info(*MRSK.app.current_container_id) }
  end
  
  desc "logs", "Show lines from app on servers"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  def logs
    # FIXME: Catch when app containers aren't running

    grep = options[:grep]

    if options[:follow]
      run_locally do
        info "Following logs on #{MRSK.primary_host}..."
        info MRSK.app.follow_logs(host: MRSK.primary_host, grep: grep)
        exec MRSK.app.follow_logs(host: MRSK.primary_host, grep: grep)
      end
    else
      since = options[:since]
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(MRSK.hosts) do |host|
        begin
          puts_by_host host, capture_with_info(*MRSK.app.logs(since: since, lines: lines, grep: grep))
        rescue SSHKit::Command::Failed
          puts_by_host host, "Nothing found"
        end
      end
    end
  end

  desc "remove", "Remove app containers and images from servers"
  def remove
    remove_containers
    remove_images
  end

  desc "remove_container [VERSION]", "Remove app container with given version from servers"
  def remove_container(version)
    on(MRSK.hosts) do
      execute *MRSK.auditor.record("app remove container #{version}"), verbosity: :debug
      execute *MRSK.app.remove_container(version: version)
    end
  end

  desc "remove_containers", "Remove all app containers from servers"
  def remove_containers
    on(MRSK.hosts) do
      execute *MRSK.auditor.record("app remove containers"), verbosity: :debug
      execute *MRSK.app.remove_containers
    end
  end

  desc "remove_images", "Remove all app images from servers"
  def remove_images
    on(MRSK.hosts) do
      execute *MRSK.auditor.record("app remove images"), verbosity: :debug
      execute *MRSK.app.remove_images
    end
  end

  desc "current_version", "Shows the version currently running"
  def current_version
    on(MRSK.hosts) { |host| puts_by_host host, capture_with_info(*MRSK.app.current_running_version).strip }
  end

  private
    def using_version(new_version)
      if new_version
        begin
          old_version = MRSK.config.version
          MRSK.config.version = new_version
          yield new_version
        ensure
          MRSK.config.version = old_version
        end
      else
        yield MRSK.config.version
      end
    end

    def most_recent_version_available(host: MRSK.primary_host)
      version = nil
      on(host) { version = capture_with_info(*MRSK.app.most_recent_version_from_available_images).strip }
      version.presence
    end

    def current_running_version(host: MRSK.primary_host)
      version = nil
      on(host) { version = capture_with_info(*MRSK.app.current_running_version).strip }
      version.presence
    end
end
