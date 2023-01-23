require "mrsk/cli/base"

class Mrsk::Cli::Accessory < Mrsk::Cli::Base
  desc "boot [NAME]", "Boot accessory service on host"
  def boot(name)
    invoke :upload, [ name ]

    accessory = MRSK.accessory(name)
    on(accessory.host) { execute *accessory.run }
  end

  desc "upload [NAME]", "Upload accessory files to host"
  def upload(name)
    accessory = MRSK.accessory(name)
    on(accessory.host) do
      accessory.files.each do |(local, remote)|
        if Pathname.new(local).exist?
          execute :mkdir, "-p", Pathname.new(remote).dirname.to_s
          upload! local.to_s, remote.to_s
        else
          raise "Missing file: #{local}"
        end
      end
    end
  end

  desc "reboot [NAME]", "Reboot accessory on host (stop container, remove container, start new container)"
  def reboot(name)
    invoke :stop, [ name ]
    invoke :remove_container, [ name ]
    invoke :boot, [ name ]
  end

  desc "start [NAME]", "Start existing accessory on host"
  def start(name)
    accessory = MRSK.accessory(name)
    on(accessory.host) { execute *accessory.start }
  end

  desc "stop [NAME]", "Stop accessory on host"
  def stop(name)
    accessory = MRSK.accessory(name)
    on(accessory.host) { execute *accessory.stop }
  end

  desc "restart [NAME]", "Restart accessory on host"
  def restart(name)
    invoke :stop, [ name ]
    invoke :start, [ name ]
  end

  desc "details [NAME]", "Display details about accessory on host"
  def details(name)
    accessory = MRSK.accessory(name)
    on(accessory.host) { puts capture_with_info(*accessory.info) }
  end

  desc "logs [NAME]", "Show log lines from accessory on host"
  option :since, aliases: "-s", desc: "Show logs since timestamp (e.g. 2013-01-02T13:23:37Z) or relative (e.g. 42m for 42 minutes)"
  option :lines, type: :numeric, aliases: "-n", desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  option :follow, aliases: "-f", desc: "Follow logs on primary server (or specific host set by --hosts)"
  def logs(name)
    accessory = MRSK.accessory(name)

    grep = options[:grep]

    if options[:follow]
      run_locally do
        info "Following logs on #{accessory.host}..."
        info accessory.follow_logs(grep: grep)
        exec accessory.follow_logs(grep: grep)
      end
    else
      since = options[:since]
      lines = options[:lines]

      on(accessory.host) do
        puts capture_with_info(*accessory.logs(since: since, lines: lines, grep: grep))
      end
    end
  end

  desc "remove [NAME]", "Remove accessory container and image from host"
  def remove(name)
    invoke :stop, [ name ]
    invoke :remove_container, [ name ]
    invoke :remove_image, [ name ]
    invoke :remove_files, [ name ]
  end

  desc "remove_container [NAME]", "Remove accessory container from host"
  def remove_container(name)
    accessory = MRSK.accessory(name)
    on(accessory.host) { execute *accessory.remove_container }
  end

  desc "remove_container [NAME]", "Remove accessory image from host"
  def remove_image(name)
    accessory = MRSK.accessory(name)
    on(accessory.host) { execute *accessory.remove_image }
  end

  desc "remove_files [NAME]", "Remove accessory directory used for uploaded files from host"
  def remove_files(name)
    accessory = MRSK.accessory(name)
    on(accessory.host) { execute :rm, "-rf", accessory.service_name }
  end
end
