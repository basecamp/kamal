class Kamal::Cli::App < Kamal::Cli::Base
  desc "boot", "Boot app on servers (or reboot app if already running)"
  def boot
    with_lock do
      say "Get most recent version available as an image...", :magenta unless options[:version]
      using_version(version_or_latest) do |version|
        say "Start container with version #{version} (or reboot if already running)...", :magenta

        # Assets are prepared in a separate step to ensure they are on all hosts before booting
        on(KAMAL.app_hosts) do
          Kamal::Cli::App::ErrorPages.new(host, self).run

          KAMAL.roles_on(host).each do |role|
            Kamal::Cli::App::Assets.new(host, role, self).run
          end
        end

        # Primary hosts and roles are returned first, so they can open the barrier
        barrier = Kamal::Cli::Healthcheck::Barrier.new

        host_boot_groups.each do |hosts|
          host_list = Array(hosts).join(",")
          run_hook "pre-app-boot", hosts: host_list

          on(hosts) do |host|
            KAMAL.roles_on(host).each do |role|
              Kamal::Cli::App::Boot.new(host, role, self, version, barrier).run
            end
          end

          run_hook "post-app-boot", hosts: host_list
          sleep KAMAL.config.boot.wait if KAMAL.config.boot.wait
        end

        # Tag once the app booted on all hosts
        on(KAMAL.app_hosts) do |host|
          execute *KAMAL.auditor.record("Tagging #{KAMAL.config.absolute_image} as the latest image"), verbosity: :debug
          execute *KAMAL.app.tag_latest_image
        end
      end
    end
  end

  desc "start", "Start existing app container on servers"
  def start
    with_lock do
      on(KAMAL.app_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          app = KAMAL.app(role: role, host: host)
          execute *KAMAL.auditor.record("Started app version #{KAMAL.config.version}"), verbosity: :debug
          execute *app.start, raise_on_non_zero_exit: false

          if role.running_proxy?
            version = capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip
            endpoint = capture_with_info(*app.container_id_for_version(version)).strip
            raise Kamal::Cli::BootError, "Failed to get endpoint for #{role} on #{host}, did the container boot?" if endpoint.empty?

            execute *app.deploy(target: endpoint)
          end
        end
      end
    end
  end

  desc "stop", "Stop app container on servers"
  def stop
    with_lock do
      on(KAMAL.app_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          app = KAMAL.app(role: role, host: host)
          execute *KAMAL.auditor.record("Stopped app", role: role), verbosity: :debug

          if role.running_proxy?
            version = capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip
            endpoint = capture_with_info(*app.container_id_for_version(version)).strip
            if endpoint.present?
              execute *app.remove, raise_on_non_zero_exit: false
            end
          end

          execute *app.stop, raise_on_non_zero_exit: false
        end
      end
    end
  end

  # FIXME: Drop in favor of just containers?
  desc "details", "Show details about app containers"
  def details
    on(KAMAL.app_hosts) do |host|
      roles = KAMAL.roles_on(host)

      roles.each do |role|
        puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).info)
      end
    end
  end

  desc "exec [CMD...]", "Execute a custom command on servers within the app container (use --help to show options)"
  option :interactive, aliases: "-i", type: :boolean, default: false, desc: "Execute command over ssh for an interactive shell (use for console/bash)"
  option :reuse, type: :boolean, default: false, desc: "Reuse currently running container instead of starting a new one"
  option :env, aliases: "-e", type: :hash, desc: "Set environment variables for the command"
  option :detach, type: :boolean, default: false, desc: "Execute command in a detached container"
  def exec(*cmd)
    pre_connect_if_required

    if (incompatible_options = [ :interactive, :reuse ].select { |key| options[:detach] && options[key] }.presence)
      raise ArgumentError, "Detach is not compatible with #{incompatible_options.join(" or ")}"
    end

    if cmd.empty?
      raise ArgumentError, "No command provided. You must specify a command to execute."
    end

    cmd = Kamal::Utils.join_commands(cmd)
    env = options[:env]
    detach = options[:detach]
    case
    when options[:interactive] && options[:reuse]
      say "Get current version of running container...", :magenta unless options[:version]
      using_version(options[:version] || current_running_version) do |version|
        say "Launching interactive command with version #{version} via SSH from existing container on #{KAMAL.primary_host}...", :magenta
        run_locally { exec KAMAL.app(role: KAMAL.primary_role, host: KAMAL.primary_host).execute_in_existing_container_over_ssh(cmd, env: env) }
      end

    when options[:interactive]
      say "Get most recent version available as an image...", :magenta unless options[:version]
      using_version(version_or_latest) do |version|
        say "Launching interactive command with version #{version} via SSH from new container on #{KAMAL.primary_host}...", :magenta
        on(KAMAL.primary_host) { execute *KAMAL.registry.login }
        run_locally do
          exec KAMAL.app(role: KAMAL.primary_role, host: KAMAL.primary_host).execute_in_new_container_over_ssh(cmd, env: env)
        end
      end

    when options[:reuse]
      say "Get current version of running container...", :magenta unless options[:version]
      using_version(options[:version] || current_running_version) do |version|
        say "Launching command with version #{version} from existing container...", :magenta

        on(KAMAL.app_hosts) do |host|
          roles = KAMAL.roles_on(host)

          roles.each do |role|
            execute *KAMAL.auditor.record("Executed cmd '#{cmd}' on app version #{version}", role: role), verbosity: :debug
            puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).execute_in_existing_container(cmd, env: env))
          end
        end
      end

    else
      say "Get most recent version available as an image...", :magenta unless options[:version]
      using_version(version_or_latest) do |version|
        say "Launching command with version #{version} from new container...", :magenta
        on(KAMAL.app_hosts) do |host|
          execute *KAMAL.registry.login

          roles = KAMAL.roles_on(host)

          roles.each do |role|
            execute *KAMAL.auditor.record("Executed cmd '#{cmd}' on app version #{version}"), verbosity: :debug
            puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).execute_in_new_container(cmd, env: env, detach: detach))
          end
        end
      end
    end
  end

  desc "containers", "Show app containers on servers"
  def containers
    on(KAMAL.app_hosts) { |host| puts_by_host host, capture_with_info(*KAMAL.app.list_containers) }
  end

  desc "stale_containers", "Detect app stale containers"
  option :stop, aliases: "-s", type: :boolean, default: false, desc: "Stop the stale containers found"
  def stale_containers
    stop = options[:stop]

    with_lock_if_stopping do
      on(KAMAL.app_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          app = KAMAL.app(role: role, host: host)
          versions = capture_with_info(*app.list_versions, raise_on_non_zero_exit: false).split("\n")
          versions -= [ capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip ]

          versions.each do |version|
            if stop
              puts_by_host host, "Stopping stale container for role #{role} with version #{version}"
              execute *app.stop(version: version), raise_on_non_zero_exit: false
            else
              puts_by_host host,  "Detected stale container for role #{role} with version #{version} (use `kamal app stale_containers --stop` to stop)"
            end
          end
        end
      end
    end
  end

  desc "images", "Show app images on servers"
  def images
    on(KAMAL.app_hosts) { |host| puts_by_host host, capture_with_info(*KAMAL.app.list_images) }
  end

  desc "logs", "Show log lines from app on servers (use --help to show options)"
  option :since, aliases: "-s", desc: "Show lines since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of lines to show from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :grep_options, desc: "Additional options supplied to grep"
  option :follow, aliases: "-f", desc: "Follow log on primary server (or specific host set by --hosts)"
  option :skip_timestamps, type: :boolean, aliases: "-T", desc: "Skip appending timestamps to logging output"
  option :container_id, desc: "Docker container ID to fetch logs"
  def logs
    # FIXME: Catch when app containers aren't running

    grep = options[:grep]
    grep_options = options[:grep_options]
    since = options[:since]
    container_id = options[:container_id]
    timestamps = !options[:skip_timestamps]

    if options[:follow]
      lines = options[:lines].presence || ((since || grep) ? nil : 10) # Default to 10 lines if since or grep isn't set

      run_locally do
        info "Following logs on #{KAMAL.primary_host}..."

        KAMAL.specific_roles ||= [ KAMAL.primary_role.name ]
        role = KAMAL.roles_on(KAMAL.primary_host).first

        app = KAMAL.app(role: role, host: host)
        info app.follow_logs(host: KAMAL.primary_host, container_id: container_id, timestamps: timestamps, lines: lines, grep: grep, grep_options: grep_options)
        exec app.follow_logs(host: KAMAL.primary_host, container_id: container_id, timestamps: timestamps, lines: lines, grep: grep, grep_options: grep_options)
      end
    else
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(KAMAL.app_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          begin
            puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).logs(container_id: container_id, timestamps: timestamps, since: since, lines: lines, grep: grep, grep_options: grep_options))
          rescue SSHKit::Command::Failed
            puts_by_host host, "Nothing found"
          end
        end
      end
    end
  end

  desc "remove", "Remove app containers and images from servers"
  def remove
    with_lock do
      stop
      remove_containers
      remove_images
      remove_app_directories
    end
  end

  desc "live", "Set the app to live mode"
  def live
    with_lock do
      on(KAMAL.proxy_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          execute *KAMAL.app(role: role, host: host).live if role.running_proxy?
        end
      end
    end
  end

  desc "maintenance", "Set the app to maintenance mode"
  option :drain_timeout, type: :numeric, desc: "How long to allow in-flight requests to complete (defaults to drain_timeout from config)"
  option :message, type: :string, desc: "Message to display to clients while stopped"
  def maintenance
    maintenance_options = { drain_timeout: options[:drain_timeout] || KAMAL.config.drain_timeout, message: options[:message] }

    with_lock do
      on(KAMAL.proxy_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          execute *KAMAL.app(role: role, host: host).maintenance(**maintenance_options) if role.running_proxy?
        end
      end
    end
  end

  desc "remove_container [VERSION]", "Remove app container with given version from servers", hide: true
  def remove_container(version)
    with_lock do
      on(KAMAL.app_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          execute *KAMAL.auditor.record("Removed app container with version #{version}", role: role), verbosity: :debug
          execute *KAMAL.app(role: role, host: host).remove_container(version: version)
        end
      end
    end
  end

  desc "remove_containers", "Remove all app containers from servers", hide: true
  def remove_containers
    with_lock do
      on(KAMAL.app_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          execute *KAMAL.auditor.record("Removed all app containers", role: role), verbosity: :debug
          execute *KAMAL.app(role: role, host: host).remove_containers
        end
      end
    end
  end

  desc "remove_images", "Remove all app images from servers", hide: true
  def remove_images
    with_lock do
      on(KAMAL.app_hosts) do
        execute *KAMAL.auditor.record("Removed all app images"), verbosity: :debug
        execute *KAMAL.app.remove_images
      end
    end
  end

  desc "remove_app_directories", "Remove the app directories from servers", hide: true
  def remove_app_directories
    with_lock do
      on(KAMAL.app_hosts) do |host|
        roles = KAMAL.roles_on(host)

        roles.each do |role|
          execute *KAMAL.auditor.record("Removed #{KAMAL.config.app_directory}", role: role), verbosity: :debug
          execute *KAMAL.server.remove_app_directory, raise_on_non_zero_exit: false
        end

        execute *KAMAL.auditor.record("Removed #{KAMAL.config.app_directory}"), verbosity: :debug
        execute *KAMAL.app.remove_proxy_app_directory, raise_on_non_zero_exit: false
      end
    end
  end

  desc "version", "Show app version currently running on servers"
  def version
    on(KAMAL.app_hosts) do |host|
      role = KAMAL.roles_on(host).first
      puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).current_running_version).strip
    end
  end

  private
    def using_version(new_version)
      if new_version
        begin
          old_version = KAMAL.config.version
          KAMAL.config.version = new_version
          yield new_version
        ensure
          KAMAL.config.version = old_version
        end
      else
        yield KAMAL.config.version
      end
    end

    def current_running_version(host: KAMAL.primary_host)
      version = nil
      on(host) do
        role = KAMAL.roles_on(host).first
        version = capture_with_info(*KAMAL.app(role: role, host: host).current_running_version).strip
      end
      version.presence
    end

    def version_or_latest
      options[:version] || KAMAL.config.latest_tag
    end

    def with_lock_if_stopping
      if options[:stop]
        with_lock { yield }
      else
        yield
      end
    end

    def host_boot_groups
      KAMAL.config.boot.limit ? KAMAL.app_hosts.each_slice(KAMAL.config.boot.limit).to_a : [ KAMAL.app_hosts ]
    end
end
