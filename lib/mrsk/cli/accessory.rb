require "mrsk/cli/base"

class Mrsk::Cli::Accessory < Mrsk::Cli::Base
  desc "boot [NAME]", "Boot accessory service on host (use NAME=all to boot all accessories)"
  def boot(name)
    if name == "all"
      MRSK.accessory_names.each { |accessory_name| boot(accessory_name) }
    else
      with_accessory(name) do |accessory|
        directories(name)
        upload(name)
        on(accessory.host) { execute *accessory.run }
      end
    end
  end

  desc "upload [NAME]", "Upload accessory files to host"
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

  desc "directories [NAME]", "Create accessory directories on host"
  def directories(name)
    with_accessory(name) do |accessory|
      on(accessory.host) do
        accessory.directories.keys.each do |host_path|
          execute *accessory.make_directory(host_path)
        end
      end
    end
  end

  desc "reboot [NAME]", "Reboot accessory on host (stop container, remove container, start new container)"
  def reboot(name)
    with_accessory(name) do |accessory|
      stop(name)
      remove_container(name)
      boot(name)
    end
  end

  desc "start [NAME]", "Start existing accessory on host"
  def start(name)
    with_accessory(name) do |accessory|
      on(accessory.host) { execute *accessory.start }
    end
  end

  desc "stop [NAME]", "Stop accessory on host"
  def stop(name)
    with_accessory(name) do |accessory|
      on(accessory.host) { execute *accessory.stop, raise_on_non_zero_exit: false }
    end
  end

  desc "restart [NAME]", "Restart accessory on host"
  def restart(name)
    with_accessory(name) do
      stop(name)
      start(name)
    end
  end

  desc "details [NAME]", "Display details about accessory on host (use NAME=all to boot all accessories)"
  def details(name)
    if name == "all"
      MRSK.accessory_names.each { |accessory_name| details(accessory_name) }
    else
      with_accessory(name) do |accessory|
        on(accessory.host) { puts capture_with_info(*accessory.info) }
      end
    end
  end

  desc "exec [NAME] [CMD]", "Execute a custom command on accessory host"
  option :method, aliases: "-m", default: "exec", desc: "Execution method: [exec] perform inside container / [run] perform in new container / [ssh] perform over ssh"
  def exec(name, cmd)
    runner = \
      case options[:method]
      when "exec" then "exec"
      when "run"  then "run_exec"
      when "ssh"  then "exec_over_ssh"
      else raise "Unknown method: #{options[:method]}"
      end.inquiry

    if runner.exec_over_ssh?
      run_locally do
        info "Launching command on #{accessory.host}"
        exec accessory.exec_over_ssh(cmd, host: accessory.host)
      end
    else
      on(accessory.host) { puts capture_with_info(*accessory.send(runner, cmd) }
    end
  end

  desc "bash [NAME]", "Start a bash session on primary host (or specific host set by --hosts)"
  def bash(name)
    with_accessory(name) do |accessory|
      run_locally do
        info "Launching bash session on #{accessory.host}"
        exec accessory.bash(host: accessory.host)
      end
    end
  end

  desc "logs [NAME]", "Show log lines from accessory on host"
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

  desc "remove [NAME]", "Remove accessory container and image from host (use NAME=all to boot all accessories)"
  def remove(name)
    if name == "all"
      MRSK.accessory_names.each { |accessory_name| remove(accessory_name) }
    else
      with_accessory(name) do
        stop(name)
        remove_container(name)
        remove_image(name)
        remove_service_directory(name)
      end
    end
  end

  desc "remove_container [NAME]", "Remove accessory container from host"
  def remove_container(name)
    with_accessory(name) do |accessory|
      on(accessory.host) { execute *accessory.remove_container }
    end
  end

  desc "remove_container [NAME]", "Remove accessory image from host"
  def remove_image(name)
    with_accessory(name) do |accessory|
      on(accessory.host) { execute *accessory.remove_image }
    end
  end

  desc "remove_service_directory [NAME]", "Remove accessory directory used for uploaded files and data directories from host"
  def remove_service_directory(name)
    with_accessory(name) do |accessory|
      on(accessory.host) { execute *accessory.remove_service_directory }
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
