class Mrsk::Cli::Traefik < Mrsk::Cli::Base
  desc "boot", "Boot Traefik on servers"
  def boot
    with_lock do
      on(MRSK.traefik_hosts) do
        execute *MRSK.registry.login
        execute *MRSK.traefik.run, raise_on_non_zero_exit: false
      end
    end
  end

  desc "reboot", "Reboot Traefik on servers (stop container, remove container, start new container)"
  def reboot
    with_lock do
      stop
      remove_container
      boot
    end
  end

  desc "start", "Start existing Traefik container on servers"
  def start
    with_lock do
      on(MRSK.traefik_hosts) do
        execute *MRSK.auditor.record("Started traefik"), verbosity: :debug
        execute *MRSK.traefik.start, raise_on_non_zero_exit: false
      end
    end
  end

  desc "stop", "Stop existing Traefik container on servers"
  def stop
    with_lock do
      on(MRSK.traefik_hosts) do
        execute *MRSK.auditor.record("Stopped traefik"), verbosity: :debug
        execute *MRSK.traefik.stop, raise_on_non_zero_exit: false
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
    on(MRSK.traefik_hosts) { |host| puts_by_host host, capture_with_info(*MRSK.traefik.info), type: "Traefik" }
  end

  desc "logs", "Show log lines from Traefik on servers"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  def logs
    grep = options[:grep]

    if options[:follow]
      run_locally do
        info "Following logs on #{MRSK.primary_host}..."
        info MRSK.traefik.follow_logs(host: MRSK.primary_host, grep: grep)
        exec MRSK.traefik.follow_logs(host: MRSK.primary_host, grep: grep)
      end
    else
      since = options[:since]
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(MRSK.traefik_hosts) do |host|
        puts_by_host host, capture(*MRSK.traefik.logs(since: since, lines: lines, grep: grep)), type: "Traefik"
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
      on(MRSK.traefik_hosts) do
        execute *MRSK.auditor.record("Removed traefik container"), verbosity: :debug
        execute *MRSK.traefik.remove_container
      end
    end
  end

  desc "remove_image", "Remove Traefik image from servers", hide: true
  def remove_image
    with_lock do
      on(MRSK.traefik_hosts) do
        execute *MRSK.auditor.record("Removed traefik image"), verbosity: :debug
        execute *MRSK.traefik.remove_image
      end
    end
  end
end
