require "active_support/core_ext/array/conversions"

class Kamal::Cli::Accessory < Kamal::Cli::Base
  desc "boot [NAME]", "Boot new accessory service on host (use NAME=all to boot all accessories)"
  def boot(name, prepare: true)
    with_lock do
      if name == "all"
        KAMAL.accessory_names.each { |accessory_name| boot(accessory_name) }
      else
        prepare(name) if prepare

        with_accessory(name) do |accessory, hosts|
          directories(name)
          upload(name)

          on(hosts) do
            execute *KAMAL.auditor.record("Booted #{name} accessory"), verbosity: :debug
            execute *accessory.ensure_env_directory
            upload! accessory.secrets_io, accessory.secrets_path, mode: "0600"
            execute *accessory.run

            if accessory.running_proxy?
              target = capture_with_info(*accessory.container_id_for(container_name: accessory.service_name, only_running: true)).strip
              execute *accessory.deploy(target: target)
            end
          end
        end
      end
    end
  end

  desc "upload [NAME]", "Upload accessory files to host", hide: true
  def upload(name)
    with_lock do
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          accessory.files.each do |(local, remote)|
            accessory.ensure_local_file_present(local)

            execute *accessory.make_directory_for(remote)
            upload! local, remote
            execute :chmod, "755", remote
          end
        end
      end
    end
  end

  desc "directories [NAME]", "Create accessory directories on host", hide: true
  def directories(name)
    with_lock do
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          accessory.directories.keys.each do |host_path|
            execute *accessory.make_directory(host_path)
          end
        end
      end
    end
  end

  desc "reboot [NAME]", "Reboot existing accessory on host (stop container, remove container, start new container; use NAME=all to boot all accessories)"
  def reboot(name)
    with_lock do
      if name == "all"
        KAMAL.accessory_names.each { |accessory_name| reboot(accessory_name) }
      else
        prepare(name)
        stop(name)
        remove_container(name)
        boot(name, prepare: false)
      end
    end
  end

  desc "start [NAME]", "Start existing accessory container on host"
  def start(name)
    with_lock do
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          execute *KAMAL.auditor.record("Started #{name} accessory"), verbosity: :debug
          execute *accessory.start
          if accessory.running_proxy?
            target = capture_with_info(*accessory.container_id_for(container_name: accessory.service_name, only_running: true)).strip
            execute *accessory.deploy(target: target)
          end
        end
      end
    end
  end

  desc "stop [NAME]", "Stop existing accessory container on host"
  def stop(name)
    with_lock do
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          execute *KAMAL.auditor.record("Stopped #{name} accessory"), verbosity: :debug
          execute *accessory.stop, raise_on_non_zero_exit: false

          if accessory.running_proxy?
            target = capture_with_info(*accessory.container_id_for(container_name: accessory.service_name, only_running: true)).strip
            execute *accessory.remove if target
          end
        end
      end
    end
  end

  desc "restart [NAME]", "Restart existing accessory container on host"
  def restart(name)
    with_lock do
      stop(name)
      start(name)
    end
  end

  desc "details [NAME]", "Show details about accessory on host (use NAME=all to show all accessories)"
  def details(name)
    if name == "all"
      KAMAL.accessory_names.each { |accessory_name| details(accessory_name) }
    else
      type = "Accessory #{name}"
      with_accessory(name) do |accessory, hosts|
        on(hosts) { puts_by_host host, capture_with_info(*accessory.info), type: type }
      end
    end
  end

  desc "exec [NAME] [CMD...]", "Execute a custom command on servers within the accessory container (use --help to show options)"
  option :interactive, aliases: "-i", type: :boolean, default: false, desc: "Execute command over ssh for an interactive shell (use for console/bash)"
  option :reuse, type: :boolean, default: false, desc: "Reuse currently running container instead of starting a new one"
  def exec(name, *cmd)
    cmd = Kamal::Utils.join_commands(cmd)
    with_accessory(name) do |accessory, hosts|
      case
      when options[:interactive] && options[:reuse]
        say "Launching interactive command via SSH from existing container...", :magenta
        run_locally { exec accessory.execute_in_existing_container_over_ssh(cmd) }

      when options[:interactive]
        say "Launching interactive command via SSH from new container...", :magenta
        run_locally { exec accessory.execute_in_new_container_over_ssh(cmd) }

      when options[:reuse]
        say "Launching command from existing container...", :magenta
        on(hosts) do |host|
          execute *KAMAL.auditor.record("Executed cmd '#{cmd}' on #{name} accessory"), verbosity: :debug
          puts_by_host host, capture_with_info(*accessory.execute_in_existing_container(cmd))
        end

      else
        say "Launching command from new container...", :magenta
        on(hosts) do |host|
          execute *KAMAL.auditor.record("Executed cmd '#{cmd}' on #{name} accessory"), verbosity: :debug
          puts_by_host host, capture_with_info(*accessory.execute_in_new_container(cmd))
        end
      end
    end
  end

  desc "logs [NAME]", "Show log lines from accessory on host (use --help to show options)"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :grep_options, desc: "Additional options supplied to grep"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  option :skip_timestamps, type: :boolean, aliases: "-T", desc: "Skip appending timestamps to logging output"
  def logs(name)
    with_accessory(name) do |accessory, hosts|
      grep = options[:grep]
      grep_options = options[:grep_options]
      timestamps = !options[:skip_timestamps]

      if options[:follow]
        run_locally do
          info "Following logs on #{hosts}..."
          info accessory.follow_logs(timestamps: timestamps, grep: grep, grep_options: grep_options)
          exec accessory.follow_logs(timestamps: timestamps, grep: grep, grep_options: grep_options)
        end
      else
        since = options[:since]
        lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

        on(hosts) do
          puts capture_with_info(*accessory.logs(timestamps: timestamps, since: since, lines: lines, grep: grep, grep_options: grep_options))
        end
      end
    end
  end

  desc "remove [NAME]", "Remove accessory container, image and data directory from host (use NAME=all to remove all accessories)"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def remove(name)
    confirming "This will remove all containers, images and data directories for #{name}. Are you sure?" do
      with_lock do
        if name == "all"
          KAMAL.accessory_names.each { |accessory_name| remove_accessory(accessory_name) }
        else
          remove_accessory(name)
        end
      end
    end
  end

  desc "remove_container [NAME]", "Remove accessory container from host", hide: true
  def remove_container(name)
    with_lock do
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          execute *KAMAL.auditor.record("Remove #{name} accessory container"), verbosity: :debug
          execute *accessory.remove_container
        end
      end
    end
  end

  desc "remove_image [NAME]", "Remove accessory image from host", hide: true
  def remove_image(name)
    with_lock do
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          execute *KAMAL.auditor.record("Removed #{name} accessory image"), verbosity: :debug
          execute *accessory.remove_image
        end
      end
    end
  end

  desc "remove_service_directory [NAME]", "Remove accessory directory used for uploaded files and data directories from host", hide: true
  def remove_service_directory(name)
    with_lock do
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          execute *accessory.remove_service_directory
        end
      end
    end
  end

  desc "upgrade", "Upgrade accessories from Kamal 1.x to 2.0 (restart them in 'kamal' network)"
  option :rolling, type: :boolean, default: false, desc: "Upgrade one host at a time"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def upgrade(name)
    confirming "This will restart all accessories" do
      with_lock do
        host_groups = options[:rolling] ? KAMAL.accessory_hosts : [ KAMAL.accessory_hosts ]
        host_groups.each do |hosts|
          host_list = Array(hosts).join(",")
          KAMAL.with_specific_hosts(hosts) do
            say "Upgrading #{name} accessories on #{host_list}...", :magenta
            reboot name
            say "Upgraded #{name} accessories on #{host_list}...", :magenta
          end
        end
      end
    end
  end

  private
    def with_accessory(name)
      if KAMAL.config.accessory(name)
        accessory = KAMAL.accessory(name)
        yield accessory, accessory_hosts(accessory)
      else
        error_on_missing_accessory(name)
      end
    end

    def error_on_missing_accessory(name)
      options = KAMAL.accessory_names.presence

      error \
        "No accessory by the name of '#{name}'" +
        (options ? " (options: #{options.to_sentence})" : "")
    end

    def accessory_hosts(accessory)
      if KAMAL.specific_hosts&.any?
        KAMAL.specific_hosts & accessory.hosts
      else
        accessory.hosts
      end
    end

    def remove_accessory(name)
      stop(name)
      remove_container(name)
      remove_image(name)
      remove_service_directory(name)
    end

    def prepare(name)
      with_accessory(name) do |accessory, hosts|
        on(hosts) do
          execute *KAMAL.registry.login(registry_config: accessory.registry)
          execute *KAMAL.docker.create_network
        rescue SSHKit::Command::Failed => e
          raise unless e.message.include?("already exists")
        end
      end
    end
end
