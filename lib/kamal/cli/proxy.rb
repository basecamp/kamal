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

        version = capture_with_info(*KAMAL.proxy.version).strip.presence

        if version && Kamal::Utils.older_version?(version, Kamal::Configuration::Proxy::Boot::MINIMUM_VERSION)
          raise "kamal-proxy version #{version} is too old, run `kamal proxy reboot` in order to update to at least #{Kamal::Configuration::Proxy::Boot::MINIMUM_VERSION}"
        end
        execute *KAMAL.proxy.ensure_apps_config_directory
        execute *KAMAL.proxy.start_or_run
      end
    end
  end

  desc "boot_config <set|get|reset>", "Manage kamal-proxy boot configuration"
  option :publish, type: :boolean, default: true, desc: "Publish the proxy ports on the host"
  option :publish_host_ip, type: :string, repeatable: true, default: nil, desc: "Host IP address to bind HTTP/HTTPS traffic to. Defaults to all interfaces"
  option :http_port, type: :numeric, default: Kamal::Configuration::Proxy::Boot::DEFAULT_HTTP_PORT, desc: "HTTP port to publish on the host"
  option :https_port, type: :numeric, default: Kamal::Configuration::Proxy::Boot::DEFAULT_HTTPS_PORT, desc: "HTTPS port to publish on the host"
  option :log_max_size, type: :string, default: Kamal::Configuration::Proxy::Boot::DEFAULT_LOG_MAX_SIZE, desc: "Max size of proxy logs"
  option :registry, type: :string, default: nil, desc: "Registry to use for the proxy image"
  option :repository, type: :string, default: nil, desc: "Repository for the proxy image"
  option :image_version, type: :string, default: nil, desc: "Version of the proxy to run"
  option :metrics_port, type: :numeric, default: nil, desc: "Port to report prometheus metrics on"
  option :debug, type: :boolean, default: false, desc: "Whether to run the proxy in debug mode"
  option :docker_options, type: :array, default: [], desc: "Docker options to pass to the proxy container", banner: "option=value option2=value2"
  def boot_config(subcommand)
    proxy_boot_config = KAMAL.config.proxy_boot

    case subcommand
    when "set"
      boot_options = [
        *(proxy_boot_config.publish_args(options[:http_port], options[:https_port], options[:publish_host_ip]) if options[:publish]),
        *(proxy_boot_config.logging_args(options[:log_max_size])),
        *("--expose=#{options[:metrics_port]}" if options[:metrics_port]),
        *options[:docker_options].map { |option| "--#{option}" }
      ]

      image = [
        options[:registry].presence,
        options[:repository].presence || proxy_boot_config.repository_name,
        proxy_boot_config.image_name
      ].compact.join("/")

      image_version = options[:image_version]

      run_command_options = { debug: options[:debug] || nil, "metrics-port": options[:metrics_port] }.compact
      run_command = "kamal-proxy run #{Kamal::Utils.optionize(run_command_options).join(" ")}" if run_command_options.any?

      on(KAMAL.proxy_hosts) do |host|
        execute(*KAMAL.proxy.ensure_proxy_directory)
        if boot_options != proxy_boot_config.default_boot_options
          upload! StringIO.new(boot_options.join(" ")), proxy_boot_config.options_file
        else
          execute *KAMAL.proxy.reset_boot_options, raise_on_non_zero_exit: false
        end

        if image != proxy_boot_config.image_default
          upload! StringIO.new(image), proxy_boot_config.image_file
        else
          execute *KAMAL.proxy.reset_image, raise_on_non_zero_exit: false
        end

        if image_version
          upload! StringIO.new(image_version), proxy_boot_config.image_version_file
        else
          execute *KAMAL.proxy.reset_image_version, raise_on_non_zero_exit: false
        end

        if run_command
          upload! StringIO.new(run_command), proxy_boot_config.run_command_file
        else
          execute *KAMAL.proxy.reset_run_command, raise_on_non_zero_exit: false
        end
      end
    when "get"

      on(KAMAL.proxy_hosts) do |host|
        puts "Host #{host}: #{capture_with_info(*KAMAL.proxy.boot_config)}"
      end
    when "reset"
      on(KAMAL.proxy_hosts) do |host|
        execute *KAMAL.proxy.reset_boot_options, raise_on_non_zero_exit: false
        execute *KAMAL.proxy.reset_image, raise_on_non_zero_exit: false
        execute *KAMAL.proxy.reset_image_version, raise_on_non_zero_exit: false
        execute *KAMAL.proxy.reset_run_command, raise_on_non_zero_exit: false
      end
    else
      raise ArgumentError, "Unknown boot_config subcommand #{subcommand}"
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

            "Stopping and removing kamal-proxy on #{host}, if running..."
            execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
            execute *KAMAL.proxy.remove_container
            execute *KAMAL.proxy.ensure_apps_config_directory

            execute *KAMAL.proxy.run
          end
          run_hook "post-proxy-reboot", hosts: host_list
        end
      end
    end
  end

  desc "upgrade", "Upgrade to kamal-proxy on servers (stop container, remove container, start new container, reboot app)", hide: true
  option :rolling, type: :boolean, default: false, desc: "Reboot proxy on hosts in sequence, rather than in parallel"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def upgrade
    invoke_options = { "version" => KAMAL.config.latest_tag }.merge(options)

    confirming "This will cause a brief outage on each host. Are you sure?" do
      host_groups = options[:rolling] ? KAMAL.hosts : [ KAMAL.hosts ]
      host_groups.each do |hosts|
        host_list = Array(hosts).join(",")
        say "Upgrading proxy on #{host_list}...", :magenta
        run_hook "pre-proxy-reboot", hosts: host_list
        on(hosts) do |host|
          execute *KAMAL.auditor.record("Rebooted proxy"), verbosity: :debug
          execute *KAMAL.registry.login

          "Stopping and removing Traefik on #{host}, if running..."
          execute *KAMAL.proxy.cleanup_traefik

          "Stopping and removing kamal-proxy on #{host}, if running..."
          execute *KAMAL.proxy.stop, raise_on_non_zero_exit: false
          execute *KAMAL.proxy.remove_container
          execute *KAMAL.proxy.remove_image
        end

        KAMAL.with_specific_hosts(hosts) do
          invoke "kamal:cli:proxy:boot", [], invoke_options
          reset_invocation(Kamal::Cli::Proxy)
          invoke "kamal:cli:app:boot", [], invoke_options
          reset_invocation(Kamal::Cli::App)
          invoke "kamal:cli:prune:all", [], invoke_options
          reset_invocation(Kamal::Cli::Prune)
        end

        run_hook "post-proxy-reboot", hosts: host_list
        say "Upgraded proxy on #{host_list}", :magenta
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
  option :skip_timestamps, type: :boolean, aliases: "-T", desc: "Skip appending timestamps to logging output"
  def logs
    grep = options[:grep]
    timestamps = !options[:skip_timestamps]

    if options[:follow]
      run_locally do
        info "Following logs on #{KAMAL.primary_host}..."
        info KAMAL.proxy.follow_logs(host: KAMAL.primary_host, timestamps: timestamps, grep: grep)
        exec KAMAL.proxy.follow_logs(host: KAMAL.primary_host, timestamps: timestamps, grep: grep)
      end
    else
      since = options[:since]
      lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

      on(KAMAL.proxy_hosts) do |host|
        puts_by_host host, capture(*KAMAL.proxy.logs(timestamps: timestamps, since: since, lines: lines, grep: grep)), type: "Proxy"
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
        remove_proxy_directory
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

  desc "remove_proxy_directory", "Remove the proxy directory from servers", hide: true
  def remove_proxy_directory
    with_lock do
      on(KAMAL.proxy_hosts) do
        execute *KAMAL.proxy.remove_proxy_directory, raise_on_non_zero_exit: false
      end
    end
  end

  private
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
