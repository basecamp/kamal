class Kamal::Cli::Proxy < Kamal::Cli::Base
  desc "boot", "Boot proxy on servers"
  def boot
    raise_unless_kamal_proxy_enabled!
    with_lock do
      on(KAMAL.hosts) do |host|
        execute *KAMAL.docker.create_network
      rescue SSHKit::Command::Failed => e
        raise unless e.message.include?("already exists")
      end

      on(KAMAL.traefik_hosts) do |host|
        execute *KAMAL.registry.login
        if KAMAL.proxy_host?(host)
          execute *KAMAL.proxy.start_or_run
        else
          execute *KAMAL.traefik.ensure_env_directory
          upload! KAMAL.traefik.secrets_io, KAMAL.traefik.secrets_path, mode: "0600"
          execute *KAMAL.traefik.start_or_run
        end
      end
    end
  end

  desc "reboot", "Reboot proxy on servers (stop container, remove container, start new container)"
  option :rolling, type: :boolean, default: false, desc: "Reboot proxy on hosts in sequence, rather than in parallel"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def reboot
    raise_unless_kamal_proxy_enabled!
    confirming "This will cause a brief outage on each host. Are you sure?" do
      with_lock do
        host_groups = options[:rolling] ? KAMAL.traefik_hosts : [ KAMAL.traefik_hosts ]
        host_groups.each do |hosts|
          host_list = Array(hosts).join(",")
          run_hook "pre-traefik-reboot", hosts: host_list
          on(hosts) do |host|
            execute *KAMAL.auditor.record("Rebooted proxy"), verbosity: :debug
            execute *KAMAL.registry.login

            "Stopping and removing Traefik on #{host}, if running..."
            execute *KAMAL.traefik.stop, raise_on_non_zero_exit: false
            execute *KAMAL.traefik.remove_container

            "Stopping and removing kamal-proxy on #{host}, if running..."
            execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
            execute *KAMAL.proxy.remove_container

            execute *KAMAL.traefik_or_proxy(host).run

            if KAMAL.proxy_host?(host)
              KAMAL.roles_on(host).select(&:running_traefik?).each do |role|
                app = KAMAL.app(role: role, host: host)

                version = capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip
                endpoint = capture_with_info(*app.container_id_for_version(version)).strip

                if endpoint.present?
                  info "Deploying #{endpoint} for role `#{role}` on #{host}..."
                  execute *KAMAL.proxy.deploy(role.container_prefix, target: endpoint)
                end
              end
            end
          end
          run_hook "post-traefik-reboot", hosts: host_list
        end
      end
    end
  end

  desc "upgrade", "Upgrade to correct proxy on servers (stop container, remove container, start new container)"
  option :rolling, type: :boolean, default: false, desc: "Reboot proxy on hosts in sequence, rather than in parallel"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def upgrade
    invoke_options = { "version" => KAMAL.config.version }.merge(options)

    raise_unless_kamal_proxy_enabled!
    confirming "This will cause a brief outage on each host. Are you sure?" do
      host_groups = options[:rolling] ? KAMAL.hosts : [ KAMAL.hosts ]
      host_groups.each do |hosts|
        host_list = Array(hosts).join(",")
        run_hook "pre-traefik-reboot", hosts: host_list
        on(hosts) do |host|
          execute *KAMAL.auditor.record("Rebooted proxy"), verbosity: :debug
          execute *KAMAL.registry.login

          "Stopping and removing Traefik on #{host}, if running..."
          execute *KAMAL.traefik.stop, raise_on_non_zero_exit: false
          execute *KAMAL.traefik.remove_container

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

        run_hook "post-traefik-reboot", hosts: host_list
      end
    end
  end

  desc "start", "Start existing proxy container on servers"
  def start
    raise_unless_kamal_proxy_enabled!
    with_lock do
      on(KAMAL.traefik_hosts) do |host|
        execute *KAMAL.auditor.record("Started proxy"), verbosity: :debug
        execute *KAMAL.traefik_or_proxy(host).start
      end
    end
  end

  desc "stop", "Stop existing proxy container on servers"
  def stop
    raise_unless_kamal_proxy_enabled!
    with_lock do
      on(KAMAL.traefik_hosts) do |host|
        execute *KAMAL.auditor.record("Stopped proxy"), verbosity: :debug
        execute *KAMAL.traefik_or_proxy(host).stop, raise_on_non_zero_exit: false
      end
    end
  end

  desc "restart", "Restart existing proxy container on servers"
  def restart
    raise_unless_kamal_proxy_enabled!
    with_lock do
      stop
      start
    end
  end

  desc "details", "Show details about proxy container from servers"
  def details
    raise_unless_kamal_proxy_enabled!
    on(KAMAL.traefik_hosts) { |host| puts_by_host host, capture_with_info(*KAMAL.traefik_or_proxy(host).info), type: "Proxy" }
  end

  desc "logs", "Show log lines from proxy on servers"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  def logs
    raise_unless_kamal_proxy_enabled!
    grep = options[:grep]

    if options[:follow]
      run_locally do
        info "Following logs on #{KAMAL.primary_host}..."
        info KAMAL.traefik_or_proxy(KAMAL.primary_host).follow_logs(host: KAMAL.primary_host, grep: grep)
        exec KAMAL.traefik_or_proxy(KAMAL.primary_host).follow_logs(host: KAMAL.primary_host, grep: grep)
      end
    else
      since = options[:since]
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(KAMAL.traefik_hosts) do |host|
        puts_by_host host, capture(*KAMAL.traefik_or_proxy(host).logs(since: since, lines: lines, grep: grep)), type: "Proxy"
      end
    end
  end

  desc "remove", "Remove proxy container and image from servers"
  def remove
    raise_unless_kamal_proxy_enabled!
    with_lock do
      stop
      remove_container
      remove_image
    end
  end

  desc "remove_container", "Remove proxy container from servers", hide: true
  def remove_container
    raise_unless_kamal_proxy_enabled!
    with_lock do
      on(KAMAL.traefik_hosts) do
        execute *KAMAL.auditor.record("Removed proxy container"), verbosity: :debug
        execute *KAMAL.proxy.remove_container
        execute *KAMAL.traefik.remove_container
      end
    end
  end

  desc "remove_image", "Remove proxy image from servers", hide: true
  def remove_image
    raise_unless_kamal_proxy_enabled!
    with_lock do
      on(KAMAL.traefik_hosts) do
        execute *KAMAL.auditor.record("Removed proxy image"), verbosity: :debug
        execute *KAMAL.proxy.remove_image
        execute *KAMAL.traefik.remove_image
      end
    end
  end

  private
    def raise_unless_kamal_proxy_enabled!
      unless KAMAL.config.proxy.enabled?
        raise "kamal proxy commands are disabled unless experimental proxy support is enabled. Use `kamal traefik` commands instead."
      end
    end

    def reset_invocation(cli_class)
      instance_variable_get("@_invocations")[cli_class].pop
    end
end
