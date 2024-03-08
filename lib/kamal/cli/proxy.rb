class Kamal::Cli::Proxy < Kamal::Cli::Base
  desc "boot", "Boot proxy on servers"
  def boot
    mutating do
      on(KAMAL.proxy_hosts) do
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
      mutating do
        host_groups = options[:rolling] ? KAMAL.proxy_hosts : [KAMAL.proxy_hosts]
        host_groups.each do |hosts|
          host_list = Array(hosts).join(",")
          run_hook "pre-proxy-reboot", hosts: host_list
          on(hosts) do
            execute *KAMAL.auditor.record("Rebooted proxy"), verbosity: :debug
            execute *KAMAL.registry.login
            execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
            execute *KAMAL.proxy.remove_container
            execute *KAMAL.proxy.run
          end
          run_hook "post-proxy-reboot", hosts: host_list
        end
      end
    end
  end

  desc "start", "Start existing proxy container on servers"
  def start
    mutating do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.auditor.record("Started proxy"), verbosity: :debug
        execute *KAMAL.proxy.start
      end
    end
  end

  desc "stop", "Stop existing proxy container on servers"
  def stop
    mutating do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.auditor.record("Stopped proxy"), verbosity: :debug
        execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
      end
    end
  end

  desc "restart", "Restart existing proxy container on servers"
  def restart
    mutating do
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
  def remove
    mutating do
      stop
      remove_container
      remove_image
    end
  end

  desc "remove_container", "Remove proxy container from servers", hide: true
  def remove_container
    mutating do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.auditor.record("Removed proxy container"), verbosity: :debug
        execute *KAMAL.proxy.remove_container
      end
    end
  end

  desc "remove_image", "Remove proxy image from servers", hide: true
  def remove_image
    mutating do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.auditor.record("Removed proxy image"), verbosity: :debug
        execute *KAMAL.proxy.remove_image
      end
    end
  end
end
