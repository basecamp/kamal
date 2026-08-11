class Kamal::Cli::Rollout < Kamal::Cli::Base
  include Controls

  desc "boot", "Boot rollout containers, without sending them any traffic"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def boot
    invoke_options = { "version" => KAMAL.config.version }.merge(options.without("skip_push"))

    if options[:skip_push]
      say "Pull app image...", :magenta
      invoke "kamal:cli:build:pull", [], invoke_options
    else
      say "Build and push app image...", :magenta
      invoke "kamal:cli:build:deliver", [], invoke_options
    end

    modify(lock: true) do
      # Not the latest tag: that points at whatever the last deploy tagged, which is the
      # live version, so rolling out `latest` would boot a copy of what is already there.
      using_version(KAMAL.config.version) do |version|
        say "Booting rollout containers with version #{version}...", :magenta

        # Disable before registering the new targets, so that a rollout never
        # inherits traffic it was not explicitly given.
        set_rollout_enabled false if KAMAL.config.rollout.on_boot.disable?

        on(KAMAL.rollout_hosts) do
          KAMAL.rollout_roles_on(host).each do |role|
            Kamal::Cli::App::Assets.new(host, role, self).run
          end
        end

        on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts, parallel: KAMAL.config.boot.parallel_roles) do |host, role|
          Kamal::Cli::Rollout::Boot.new(host, role, self, version).run
        end

        if KAMAL.config.rollout.on_boot.disable?
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
      on(rollout_proxy_hosts) do |host|
        role = KAMAL.rollout_roles_on(host).find(&:running_proxy?)
        execute *KAMAL.app(role: role, host: host).rollout_set(percent: percent, list: list)
      end
    end
  end

  desc "disable", "Stop sending traffic to the rollout, remembering its split"
  def disable
    with_lock do
      set_rollout_enabled false
      say "Rollout disabled. Run `kamal rollout enable` to send it traffic again.", :magenta
    end
  end

  desc "enable", "Send traffic to the rollout again, using the split it was last set to"
  def enable
    with_lock do
      set_rollout_enabled true
    end
  end

  desc "remove", "Unregister the rollout and remove its containers"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def remove
    confirming "This will stop the rollout and remove its containers. Are you sure?" do
      modify(lock: true) do
        unregister_rollout

        on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts) do |host, role|
          app = KAMAL.app(role: role, host: host)
          execute *app.stop, raise_on_non_zero_exit: false
          execute *app.remove_containers
        end
      end
    end
  end

  desc "details", "Show the current split and the rollout containers"
  def details
    if KAMAL.rollout_roles.empty?
      say "No roles take part in rollouts", :yellow
      return
    end

    quiet = options[:quiet]

    on(rollout_proxy_hosts) do |host|
      role = KAMAL.rollout_roles_on(host).find(&:running_proxy?)
      listed = capture_with_info(*KAMAL.app(role: role, host: host).proxy_list, raise_on_non_zero_exit: false)
      puts_by_host host, Kamal::Cli::Rollout.split_summary(listed, role.proxy_service_name), quiet: quiet
    end

    on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts) do |host, role|
      puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).info), quiet: quiet
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
    grep_options = options[:grep_options]
    timestamps = !options[:skip_timestamps]
    quiet = options[:quiet]
    lines = options[:lines].presence || ((since || grep) ? nil : 100)

    on_roles(KAMAL.rollout_roles, hosts: KAMAL.rollout_hosts) do |host, role|
      begin
        puts_by_host host, capture_with_info(*KAMAL.app(role: role, host: host).logs(
          timestamps: timestamps, since: since, lines: lines,
          grep: grep, grep_options: grep_options)), quiet: quiet
      rescue SSHKit::Command::Failed
        puts_by_host host, "Nothing found", quiet: quiet
      end
    end
  end

  def self.split_summary(listed, service_name)
    service = JSON.parse(listed.presence || "{}")["services"]&.dig(service_name)
    return "No rollout registered" if service.nil? || service["rollout_target"].blank?

    parts = []
    parts << "#{service["rollout_percentage"]}%" if service["rollout_percentage"].to_i > 0
    parts << "list of #{service["rollout_allowlist"].size}" if service["rollout_allowlist"].present?
    parts << "no split set" if parts.empty?
    parts << (service["rollout_enabled"] ? "enabled" : "disabled")

    "Rollout #{parts.join(", ")} -> #{service["rollout_target"]}"
  rescue JSON::ParserError
    "Could not read the rollout split"
  end
end
