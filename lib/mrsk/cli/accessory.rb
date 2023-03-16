class Mrsk::Cli::Accessory < Mrsk::Cli::Base
  desc "boot [NAME]", "Boot new accessory service on host (use NAME=all to boot all accessories)"
  def boot(name)
    if name == "all"
      MRSK.accessory_names.each { |accessory_name| boot(accessory_name) }
    else
      with_accessory(name) do |accessory|
        directories(name)
        upload(name)

        on(accessory.host) do
          execute *MRSK.auditor.record("Booted #{name} accessory"), verbosity: :debug
          execute *accessory.run
        end

        audit_broadcast "Booted accessory #{name}" unless options[:skip_broadcast]
      end
    end
  end

  desc "upload [NAME]", "Upload accessory files to host", hide: true
  def upload(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        accessory.files.each do |(local, remote)|
          accessory.ensure_local_file_present(local)

          execute *accessory.make_directory_for(remote)
          upload! local, remote
          execute :chmod, "755", remote
        end
      end
    end
  end

  desc "directories [NAME]", "Create accessory directories on host", hide: true
  def directories(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        accessory.directories.keys.each do |host_path|
          execute *accessory.make_directory(host_path)
        end
      end
    end
  end

  desc "reboot [NAME]", "Reboot existing accessory on host (stop container, remove container, start new container)"
  def reboot(name)
    with_accessory(name) do |accessory|
      stop(name)
      remove_container(name)
      boot(name)
    end
  end

  desc "start [NAME]", "Start existing accessory container on host"
  def start(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        execute *MRSK.auditor.record("Started #{name} accessory"), verbosity: :debug
        execute *accessory.start
      end
    end
  end

  desc "stop [NAME]", "Stop existing accessory container on host"
  def stop(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        execute *MRSK.auditor.record("Stopped #{name} accessory"), verbosity: :debug
        execute *accessory.stop, raise_on_non_zero_exit: false
      end
    end
  end

  desc "restart [NAME]", "Restart existing accessory container on host"
  def restart(name)
    with_accessory(name) do
      stop(name)
      start(name)
    end
  end

  desc "details [NAME]", "Show details about accessory on host (use NAME=all to show all accessories)"
  def details(name)
    if name == "all"
      MRSK.accessory_names.each { |accessory_name| details(accessory_name) }
    else
      with_accessory(name) do |accessory|
        on(accessory.host) { puts capture_with_info(*accessory.info) }
      end
    end
  end

  desc "exec [NAME] [CMD]", "Execute a custom command on servers (use --help to show options)"
  option :interactive, aliases: "-i", type: :boolean, default: false, desc: "Execute command over ssh for an interactive shell (use for console/bash)"
  option :reuse, type: :boolean, default: false, desc: "Reuse currently running container instead of starting a new one"
  def exec(name, cmd)
    with_accessory(name) do |accessory|
      case
      when options[:interactive] && options[:reuse]
        say "Launching interactive command with via SSH from existing container...", :magenta
        run_locally { exec accessory.execute_in_existing_container_over_ssh(cmd) }

      when options[:interactive]
        say "Launching interactive command via SSH from new container...", :magenta
        run_locally { exec accessory.execute_in_new_container_over_ssh(cmd) }

      when options[:reuse]
        say "Launching command from existing container...", :magenta
        on(accessory.host) do
          execute *MRSK.auditor.record("Executed cmd '#{cmd}' on #{name} accessory"), verbosity: :debug
          capture_with_info(*accessory.execute_in_existing_container(cmd))
        end

      else
        say "Launching command from new container...", :magenta
        on(accessory.host) do
          execute *MRSK.auditor.record("Executed cmd '#{cmd}' on #{name} accessory"), verbosity: :debug
          capture_with_info(*accessory.execute_in_new_container(cmd))
        end
      end
    end
  end

  desc "logs [NAME]", "Show log lines from accessory on host (use --help to show options)"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  def logs(name)
    with_accessory(name) do |accessory|
      grep = options[:grep]

      if options[:follow]
        run_locally do
          info "Following logs on #{accessory.host}..."
          info accessory.follow_logs(grep: grep)
          exec accessory.follow_logs(grep: grep)
        end
      else
        since = options[:since]
        lines = options[:lines].presence || ((since || grep) ? nil : 100) # Default to 100 lines if since or grep isn't set

        on(accessory.host) do
          puts capture_with_info(*accessory.logs(since: since, lines: lines, grep: grep))
        end
      end
    end
  end

  desc "remove [NAME]", "Remove accessory container, image and data directory from host (use NAME=all to remove all accessories)"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def remove(name)
    if name == "all"
      MRSK.accessory_names.each { |accessory_name| remove(accessory_name) }
    else
      if options[:confirmed] || ask("This will remove all containers, images and data directories for #{name}. Are you sure?", limited_to: %w( y N ), default: "N") == "y"
        with_accessory(name) do
          stop(name)
          remove_container(name)
          remove_image(name)
          remove_service_directory(name)
        end
      end
    end
  end

  desc "remove_container [NAME]", "Remove accessory container from host", hide: true
  def remove_container(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        execute *MRSK.auditor.record("Remove #{name} accessory container"), verbosity: :debug
        execute *accessory.remove_container
      end
    end
  end

  desc "remove_image [NAME]", "Remove accessory image from host", hide: true
  def remove_image(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        execute *MRSK.auditor.record("Removed #{name} accessory image"), verbosity: :debug
        execute *accessory.remove_image
      end
    end
  end

  desc "remove_service_directory [NAME]", "Remove accessory directory used for uploaded files and data directories from host", hide: true
  def remove_service_directory(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        execute *accessory.remove_service_directory
      end
    end
  end

  private
    def with_accessory(name)
      if accessory = MRSK.accessory(name)
        yield accessory
      else
        error_on_missing_accessory(name)
      end
    end

    def error_on_missing_accessory(name)
      options = MRSK.accessory_names.presence

      error \
        "No accessory by the name of '#{name}'" +
        (options ? " (options: #{options.to_sentence})" : "")
    end
end
