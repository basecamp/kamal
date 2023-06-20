class Mrsk::Cli::App < Mrsk::Cli::Base
  desc "boot", "Boot app on servers (or reboot app if already running)"
  def boot
    mutating do
      hold_lock_on_error do
        say "Get most recent version available as an image...", :magenta unless options[:version]
        using_version(version_or_latest) do |version|
          say "Start container with version #{version} using a #{MRSK.config.readiness_delay}s readiness delay (or reboot if already running)...", :magenta

          on(MRSK.hosts) do
            execute *MRSK.auditor.record("Tagging #{MRSK.config.absolute_image} as the latest image"), verbosity: :debug
            execute *MRSK.app.tag_current_as_latest
          end

          on(MRSK.hosts, **MRSK.boot_strategy) do |host|
            roles = MRSK.roles_on(host)

            roles.each do |role|
              app = MRSK.app(role: role)
              auditor = MRSK.auditor(role: role)

              if capture_with_info(*app.container_id_for_version(version, only_running: true), raise_on_non_zero_exit: false).present?
                tmp_version = "#{version}_replaced_#{SecureRandom.hex(8)}"
                info "Renaming container #{version} to #{tmp_version} as already deployed on #{host}"
                execute *auditor.record("Renaming container #{version} to #{tmp_version}"), verbosity: :debug
                execute *app.rename_container(version: version, new_version: tmp_version)
              end

              execute *auditor.record("Booted app version #{version}"), verbosity: :debug

              old_version = capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip
              execute *app.start_or_run(hostname: "#{host}-#{SecureRandom.hex(6)}")

              Mrsk::Utils::HealthcheckPoller.wait_for_healthy(pause_after_ready: true) { capture_with_info(*app.status(version: version)) }

              execute *app.stop(version: old_version), raise_on_non_zero_exit: false if old_version.present?
            end
          end
        end
      end
    end
  end

  desc "start", "Start existing app container on servers"
  def start
    mutating do
      on(MRSK.hosts) do |host|
        roles = MRSK.roles_on(host)

        roles.each do |role|
          execute *MRSK.auditor.record("Started app version #{MRSK.config.version}"), verbosity: :debug
          execute *MRSK.app(role: role).start, raise_on_non_zero_exit: false
        end
      end
    end
  end

  desc "stop", "Stop app container on servers"
  def stop
    mutating do
      on(MRSK.hosts) do |host|
        roles = MRSK.roles_on(host)

        roles.each do |role|
          execute *MRSK.auditor.record("Stopped app", role: role), verbosity: :debug
          execute *MRSK.app(role: role).stop, raise_on_non_zero_exit: false
        end
      end
    end
  end

  # FIXME: Drop in favor of just containers?
  desc "details", "Show details about app containers"
  def details
    on(MRSK.hosts) do |host|
      roles = MRSK.roles_on(host)

      roles.each do |role|
        puts_by_host host, capture_with_info(*MRSK.app(role: role).info)
      end
    end
  end

  desc "exec [CMD]", "Execute a custom command on servers (use --help to show options)"
  option :interactive, aliases: "-i", type: :boolean, default: false, desc: "Execute command over ssh for an interactive shell (use for console/bash)"
  option :reuse, type: :boolean, default: false, desc: "Reuse currently running container instead of starting a new one"
  def exec(cmd)
    case
    when options[:interactive] && options[:reuse]
      say "Get current version of running container...", :magenta unless options[:version]
      using_version(options[:version] || current_running_version) do |version|
        say "Launching interactive command with version #{version} via SSH from existing container on #{MRSK.primary_host}...", :magenta
        run_locally { exec MRSK.app(role: "web").execute_in_existing_container_over_ssh(cmd, host: MRSK.primary_host) }
      end

    when options[:interactive]
      say "Get most recent version available as an image...", :magenta unless options[:version]
      using_version(version_or_latest) do |version|
        say "Launching interactive command with version #{version} via SSH from new container on #{MRSK.primary_host}...", :magenta
        run_locally { exec MRSK.app.execute_in_new_container_over_ssh(cmd, host: MRSK.primary_host) }
      end

    when options[:reuse]
      say "Get current version of running container...", :magenta unless options[:version]
      using_version(options[:version] || current_running_version) do |version|
        say "Launching command with version #{version} from existing container...", :magenta

        on(MRSK.hosts) do |host|
          roles = MRSK.roles_on(host)

          roles.each do |role|
            execute *MRSK.auditor.record("Executed cmd '#{cmd}' on app version #{version}", role: role), verbosity: :debug
            puts_by_host host, capture_with_info(*MRSK.app(role: role).execute_in_existing_container(cmd))
          end
        end
      end

    else
      say "Get most recent version available as an image...", :magenta unless options[:version]
      using_version(version_or_latest) do |version|
        say "Launching command with version #{version} from new container...", :magenta
        on(MRSK.hosts) do |host|
          execute *MRSK.auditor.record("Executed cmd '#{cmd}' on app version #{version}"), verbosity: :debug
          puts_by_host host, capture_with_info(*MRSK.app.execute_in_new_container(cmd))
        end
      end
    end
  end

  desc "containers", "Show app containers on servers"
  def containers
    on(MRSK.hosts) { |host| puts_by_host host, capture_with_info(*MRSK.app.list_containers) }
  end

  desc "stale_containers", "Detect app stale containers"
  option :stop, aliases: "-s", type: :boolean, default: false, desc: "Stop the stale containers found"
  def stale_containers
    mutating do
      stop = options[:stop]

      cli = self

      on(MRSK.hosts) do |host|
        roles = MRSK.roles_on(host)

        roles.each do |role|
          cli.send(:stale_versions, host: host, role: role).each do |version|
            if stop
              puts_by_host host, "Stopping stale container for role #{role} with version #{version}"
              execute *MRSK.app(role: role).stop(version: version), raise_on_non_zero_exit: false
            else
              puts_by_host host,  "Detected stale container for role #{role} with version #{version} (use `mrsk app stale_containers --stop` to stop)"
            end
          end
        end
      end
    end
  end

  desc "images", "Show app images on servers"
  def images
    on(MRSK.hosts) { |host| puts_by_host host, capture_with_info(*MRSK.app.list_images) }
  end

  desc "logs", "Show log lines from app on servers (use --help to show options)"
  option :since, aliases: "-s", desc: "Show lines since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of lines to show from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :follow, aliases: "-f", desc: "Follow log on primary server (or specific host set by --hosts)"
  def logs
    # FIXME: Catch when app containers aren't running

    grep = options[:grep]

    if options[:follow]
      run_locally do
        info "Following logs on #{MRSK.primary_host}..."

        MRSK.specific_roles ||= ["web"]
        role = MRSK.roles_on(MRSK.primary_host).first

        info MRSK.app(role: role).follow_logs(host: MRSK.primary_host, grep: grep)
        exec MRSK.app(role: role).follow_logs(host: MRSK.primary_host, grep: grep)
      end
    else
      since = options[:since]
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(MRSK.hosts) do |host|
        roles = MRSK.roles_on(host)

        roles.each do |role|
          begin
            puts_by_host host, capture_with_info(*MRSK.app(role: role).logs(since: since, lines: lines, grep: grep))
          rescue SSHKit::Command::Failed
            puts_by_host host, "Nothing found"
          end
        end
      end
    end
  end

  desc "remove", "Remove app containers and images from servers"
  def remove
    mutating do
      stop
      remove_containers
      remove_images
    end
  end

  desc "remove_container [VERSION]", "Remove app container with given version from servers", hide: true
  def remove_container(version)
    mutating do
      on(MRSK.hosts) do |host|
        roles = MRSK.roles_on(host)

        roles.each do |role|
          execute *MRSK.auditor.record("Removed app container with version #{version}", role: role), verbosity: :debug
          execute *MRSK.app(role: role).remove_container(version: version)
        end
      end
    end
  end

  desc "remove_containers", "Remove all app containers from servers", hide: true
  def remove_containers
    mutating do
      on(MRSK.hosts) do |host|
        roles = MRSK.roles_on(host)

        roles.each do |role|
          execute *MRSK.auditor.record("Removed all app containers", role: role), verbosity: :debug
          execute *MRSK.app(role: role).remove_containers
        end
      end
    end
  end

  desc "remove_images", "Remove all app images from servers", hide: true
  def remove_images
    mutating do
      on(MRSK.hosts) do
        execute *MRSK.auditor.record("Removed all app images"), verbosity: :debug
        execute *MRSK.app.remove_images
      end
    end
  end

  desc "version", "Show app version currently running on servers"
  def version
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

    def current_running_version(host: MRSK.primary_host)
      version = nil
      on(host) { version = capture_with_info(*MRSK.app.current_running_version).strip }
      version.presence
    end

    def stale_versions(host:, role:)
      versions = nil
      on(host) do
        versions = \
          capture_with_info(*MRSK.app(role: role).list_versions, raise_on_non_zero_exit: false)
          .split("\n")
          .drop(1)
      end
      versions
    end

    def version_or_latest
      options[:version] || "latest"
    end
end
