class Kamal::Cli::Traefik < Kamal::Cli::Base
  desc "boot", "Boot Traefik on servers"
  def boot
    with_lock do
      on(KAMAL.traefik_hosts) do
        execute *KAMAL.registry.login
        execute *KAMAL.traefik.start_or_run
      end
    end
  end

  desc "reboot", "Reboot Traefik on servers (stop container, remove container, start new container)"
  option :rolling, type: :boolean, default: false, desc: "Reboot traefik on hosts in sequence, rather than in parallel"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def reboot
    confirming "This will cause a brief outage on each host. Are you sure?" do
      with_lock do
        host_groups = options[:rolling] ? KAMAL.traefik_hosts : [ KAMAL.traefik_hosts ]
        host_groups.each do |hosts|
          host_list = Array(hosts).join(",")
          run_hook "pre-traefik-reboot", hosts: host_list
          on(hosts) do
            execute *KAMAL.auditor.record("Rebooted traefik"), verbosity: :debug
            execute *KAMAL.registry.login
            execute *KAMAL.traefik.stop, raise_on_non_zero_exit: false
            execute *KAMAL.traefik.remove_container
            execute *KAMAL.traefik.run
          end
          run_hook "post-traefik-reboot", hosts: host_list
        end
      end
    end
  end

  desc "start", "Start existing Traefik container on servers"
  def start
    with_lock do
      on(KAMAL.traefik_hosts) do
        execute *KAMAL.auditor.record("Started traefik"), verbosity: :debug
        execute *KAMAL.traefik.start
      end
    end
  end

  desc "stop", "Stop existing Traefik container on servers"
  def stop
    with_lock do
      on(KAMAL.traefik_hosts) do
        execute *KAMAL.auditor.record("Stopped traefik"), verbosity: :debug
        execute *KAMAL.traefik.stop, raise_on_non_zero_exit: false
      end
    end
  end

  desc "restart", "Restart existing Traefik container on servers"
  def restart
    with_lock do
      stop
      start
    end
  end

  desc "details", "Show details about Traefik container from servers"
  def details
    on(KAMAL.traefik_hosts) { |host| puts_by_host host, capture_with_info(*KAMAL.traefik.info), type: "Traefik" }
  end

  desc "logs", "Show log lines from Traefik on servers"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :grep_options, aliases: "-o", desc: "Additional options supplied to grep"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  def logs
    grep = options[:grep]
    grep_options = options[:grep_options]

    if options[:follow]
      run_locally do
        info "Following logs on #{KAMAL.primary_host}..."
        info KAMAL.traefik.follow_logs(host: KAMAL.primary_host, grep: grep, grep_options: grep_options)
        exec KAMAL.traefik.follow_logs(host: KAMAL.primary_host, grep: grep, grep_options: grep_options)
      end
    else
      since = options[:since]
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(KAMAL.traefik_hosts) do |host|
        puts_by_host host, capture(*KAMAL.traefik.logs(since: since, lines: lines, grep: grep, grep_options: grep_options)), type: "Traefik"
      end
    end
  end

  desc "remove", "Remove Traefik container and image from servers"
  def remove
    with_lock do
      stop
      remove_container
      remove_image
    end
  end

  desc "remove_container", "Remove Traefik container from servers", hide: true
  def remove_container
    with_lock do
      on(KAMAL.traefik_hosts) do
        execute *KAMAL.auditor.record("Removed traefik container"), verbosity: :debug
        execute *KAMAL.traefik.remove_container
      end
    end
  end

  desc "remove_image", "Remove Traefik image from servers", hide: true
  def remove_image
    with_lock do
      on(KAMAL.traefik_hosts) do
        execute *KAMAL.auditor.record("Removed traefik image"), verbosity: :debug
        execute *KAMAL.traefik.remove_image
      end
    end
  end
end
