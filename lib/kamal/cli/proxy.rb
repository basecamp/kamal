class Kamal::Cli::Proxy < Kamal::Cli::Base
  desc "boot", "Boot proxy on servers"
  def boot
    with_lock do
      on(KAMAL.hosts) do |host|
        execute *KAMAL.docker.create_network
      rescue SSHKit::Command::Failed => e
        raise unless e.message.include?("already exists")
      end

      on(KAMAL.proxy_hosts) do |host|
        execute *KAMAL.registry.login
        execute *KAMAL.proxy.start_or_run
      end
    end
  end

  desc "reboot", "Reboot proxy on servers (stop container, remove container, start new container)"
  option :rolling, type: :boolean, default: false, desc: "Reboot proxy on hosts in sequence, rather than in parallel"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def reboot
    confirming "This will cause a brief outage on each host. Are you sure?" do
      with_lock do
        host_groups = options[:rolling] ? KAMAL.proxy_hosts : [ KAMAL.proxy_hosts ]
        host_groups.each do |hosts|
          host_list = Array(hosts).join(",")
          run_hook "pre-proxy-reboot", hosts: host_list
          on(hosts) do |host|
            execute *KAMAL.auditor.record("Rebooted proxy"), verbosity: :debug
            execute *KAMAL.registry.login

            "Stopping and removing Traefik on #{host}, if running..."
            execute *KAMAL.proxy.cleanup_traefik

            "Stopping and removing kamal-proxy on #{host}, if running..."
            execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
            execute *KAMAL.proxy.remove_container

            execute *KAMAL.proxy.run

            KAMAL.roles_on(host).select(&:running_proxy?).each do |role|
              app = KAMAL.app(role: role, host: host)

              version = capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip
              endpoint = capture_with_info(*app.container_id_for_version(version)).strip

              if endpoint.present?
                info "Deploying #{endpoint} for role `#{role}` on #{host}..."
                execute *KAMAL.proxy.deploy(role.container_prefix, target: endpoint)
              end
            end
          end
          run_hook "post-proxy-reboot", hosts: host_list
        end
      end
    end
  end

  desc "upgrade", "Upgrade to correct proxy on servers (stop container, remove container, start new container)"
  option :rolling, type: :boolean, default: false, desc: "Reboot proxy on hosts in sequence, rather than in parallel"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def upgrade
    invoke_options = { "version" => KAMAL.config.version }.merge(options)

    confirming "This will cause a brief outage on each host. Are you sure?" do
      host_groups = options[:rolling] ? KAMAL.hosts : [ KAMAL.hosts ]
      host_groups.each do |hosts|
        host_list = Array(hosts).join(",")
        run_hook "pre-proxy-reboot", hosts: host_list
        on(hosts) do |host|
          execute *KAMAL.auditor.record("Rebooted proxy"), verbosity: :debug
          execute *KAMAL.registry.login

          "Stopping and removing Traefik on #{host}, if running..."
          execute *KAMAL.proxy.cleanup_traefik

          "Stopping and removing kamal-proxy on #{host}, if running..."
          execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
          execute *KAMAL.proxy.remove_container
        end

        invoke "kamal:cli:proxy:boot", [], invoke_options.merge("hosts" => host_list)
        reset_invocation(Kamal::Cli::Proxy)
        invoke "kamal:cli:app:boot", [], invoke_options.merge("hosts" => host_list, version: KAMAL.config.latest_tag)
        reset_invocation(Kamal::Cli::App)
        invoke "kamal:cli:prune:all", [], invoke_options.merge("hosts" => host_list)
        reset_invocation(Kamal::Cli::Prune)

        run_hook "post-proxy-reboot", hosts: host_list
      end
    end
  end

  desc "start", "Start existing proxy container on servers"
  def start
    with_lock do
      on(KAMAL.proxy_hosts) do |host|
        execute *KAMAL.auditor.record("Started proxy"), verbosity: :debug
        execute *KAMAL.proxy.start
      end
    end
  end

  desc "stop", "Stop existing proxy container on servers"
  def stop
    with_lock do
      on(KAMAL.proxy_hosts) do |host|
        execute *KAMAL.auditor.record("Stopped proxy"), verbosity: :debug
        execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
      end
    end
  end

  desc "restart", "Restart existing proxy container on servers"
  def restart
    with_lock do
      stop
      start
    end
  end

  desc "details", "Show details about proxy container from servers"
  def details
    on(KAMAL.proxy_hosts) { |host| puts_by_host host, capture_with_info(*KAMAL.proxy.info), type: "Proxy" }
  end

  desc "logs", "Show log lines from proxy on servers"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  def logs
    grep = options[:grep]

    if options[:follow]
      run_locally do
        info "Following logs on #{KAMAL.primary_host}..."
        info KAMAL.proxy.follow_logs(host: KAMAL.primary_host, grep: grep)
        exec KAMAL.proxy.follow_logs(host: KAMAL.primary_host, grep: grep)
      end
    else
      since = options[:since]
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(KAMAL.proxy_hosts) do |host|
        puts_by_host host, capture(*KAMAL.proxy.logs(since: since, lines: lines, grep: grep)), type: "Proxy"
      end
    end
  end

  desc "remove", "Remove proxy container and image from servers"
  option :force, type: :boolean, default: false, desc: "Force removing proxy when apps are still installed"
  def remove
    with_lock do
      if removal_allowed?(options[:force])
        stop
        remove_container
        remove_image
        remove_host_directory
      end
    end
  end

  desc "remove_container", "Remove proxy container from servers", hide: true
  def remove_container
    with_lock do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.auditor.record("Removed proxy container"), verbosity: :debug
        execute *KAMAL.proxy.remove_container
      end
    end
  end

  desc "remove_image", "Remove proxy image from servers", hide: true
  def remove_image
    with_lock do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.auditor.record("Removed proxy image"), verbosity: :debug
        execute *KAMAL.proxy.remove_image
      end
    end
  end

  desc "remove_host_directory", "Remove proxy directory from servers", hide: true
  def remove_host_directory
    with_lock do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.auditor.record("Removed #{KAMAL.config.proxy_directory}"), verbosity: :debug
        execute *KAMAL.proxy.remove_host_directory
      end
    end
  end

  private
    def reset_invocation(cli_class)
      instance_variable_get("@_invocations")[cli_class].pop
    end

    def removal_allowed?(force)
      on(KAMAL.proxy_hosts) do |host|
        app_count = capture_with_info(*KAMAL.server.app_directory_count).chomp.to_i
        raise "The are other applications installed on #{host}" if app_count > 0
      end

      true
    rescue SSHKit::Runner::ExecuteError => e
      raise unless e.message.include?("The are other applications installed on")

      if force
        say "Forcing, so removing the proxy, even though other apps are installed", :magenta
      else
        say "Not removing the proxy, as other apps are installed, ignore this check with kamal proxy remove --force", :magenta
      end

      force
    end
end
