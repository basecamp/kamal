class Kamal::Cli::Rollout < Kamal::Cli::Base
  desc "boot", "Boot rollout containers, without sending them any traffic"
  option :version, desc: "Version to roll out (defaults to the latest tag)"
  def boot
    modify(lock: true) do
      using_version(version_or_latest) do |version|
        say "Booting rollout containers with version #{version}...", :magenta

        # Tear down any open split before registering the new targets, so that a
        # rollout never inherits traffic it was not explicitly given.
        reset_split if KAMAL.config.rollout.on_boot.reset?

        on(KAMAL.rollout_hosts) do
          KAMAL.rollout_roles_on(host).each do |role|
            Kamal::Cli::App::Assets.new(host, role, self).run
          end
        end

        on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts, parallel: KAMAL.config.boot.parallel_roles) do |host, role|
          Kamal::Cli::Rollout::Boot.new(host, role, self, version).run
        end

        if KAMAL.config.rollout.on_boot.reset?
          say "Rollout booted. It takes no traffic until you run `kamal rollout set`.", :magenta
        else
          say "Rollout booted.", :magenta
        end
      end
    end
  end

  desc "set", "Send a share of traffic to the rollout"
  option :percent, type: :numeric, desc: "Percentage of the split values to route to the rollout"
  option :list, type: :array, desc: "Split values to route to the rollout, whatever the percentage"
  def set
    percent, list = options[:percent], options[:list]

    if percent.nil? && list.blank?
      raise Kamal::ConfigurationError, "Set --percent, --list, or both"
    end

    if percent && percent > KAMAL.config.rollout.max_percent
      raise Kamal::ConfigurationError,
        "--percent #{percent} exceeds rollout/max_percent of #{KAMAL.config.rollout.max_percent}"
    end

    with_lock do
      on(proxy_rollout_hosts) do |host|
        role = KAMAL.rollout_roles_on(host).find(&:running_proxy?)
        execute *KAMAL.app(role: role, host: host).rollout_set(percent: percent, list: list)
      end
    end
  end

  desc "stop", "Stop the rollout and unregister it from the proxy, leaving its containers running"
  def stop
    with_lock do
      reset_split
      say "Rollout stopped. Its containers are still running — boot it again to send it traffic.", :magenta
    end
  end

  desc "remove", "Stop the rollout and remove its containers"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def remove
    confirming "This will stop the rollout and remove its containers. Are you sure?" do
      modify(lock: true) do
        reset_split

        on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts) do |host, role|
          app = KAMAL.app(role: role, host: host)
          execute *app.stop, raise_on_non_zero_exit: false
          execute *app.remove_containers
        end
      end
    end
  end

  desc "details", "Show details about rollout containers"
  def details
    if KAMAL.rollout_roles.empty?
      say "No roles take part in rollouts", :yellow
      return
    end

    on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts) do |host, role|
      puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).info), quiet: options[:quiet]
    end
  end

  desc "logs", "Show log lines from the rollout containers"
  option :since, aliases: "-s", desc: "Show lines since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of lines to show from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only"
  option :grep_options, desc: "Additional options supplied to grep"
  option :skip_timestamps, type: :boolean, aliases: "-T", desc: "Skip appending timestamps to logging output"
  def logs
    since = options[:since]
    grep = options[:grep]
    lines = options[:lines].presence || ((since || grep) ? nil : 100)

    on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts) do |host, role|
      begin
        puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).logs(
          timestamps: !options[:skip_timestamps], since: since, lines: lines,
          grep: grep, grep_options: options[:grep_options])), quiet: options[:quiet]
      rescue SSHKit::Command::Failed
        puts_by_host host, "Nothing found", quiet: options[:quiet]
      end
    end
  end

  private
    def reset_split
      on(proxy_rollout_hosts) do |host|
        role = KAMAL.rollout_roles_on(host).find(&:running_proxy?)
        execute *KAMAL.app(role: role, host: host).rollout_stop, raise_on_non_zero_exit: false
      end
    end

    def proxy_rollout_hosts
      KAMAL.rollout_roles.select(&:running_proxy?).flat_map(&:hosts).uniq & KAMAL.rollout_hosts
    end
end
