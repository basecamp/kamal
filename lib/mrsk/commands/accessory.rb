require "mrsk/commands/base"

class Mrsk::Commands::Accessory < Mrsk::Commands::Base
  attr_reader :accessory_config
  delegate :service_name, :image, :host, :port, :files, :directories, :env_args, :volume_args, :label_args, to: :accessory_config

  def initialize(config, name:)
    super(config)
    @accessory_config = config.accessory(name)
  end

  def run
    docker :run, 
      "--name", service_name,
      "-d",
      "--restart", "unless-stopped",
      "-p", port,
      *env_args,
      *volume_args,
      *label_args,
      image
  end

  def start
    docker :container, :start, service_name
  end

  def stop
    docker :container, :stop, service_name
  end

  def info
    docker :ps, *service_filter
  end


  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      docker(:logs, service_name, (" --since #{since}" if since), (" -n #{lines}" if lines), "-t", "2>&1"),
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(grep: nil)
    run_over_ssh pipe(
      docker(:logs, service_name, "-t", "-n", "10", "-f", "2>&1"),
      (%(grep "#{grep}") if grep)
    ).join(" ")
  end


  def execute_in_existing_container(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      service_name,
      *command
  end

  def execute_in_new_container(*command, interactive: false)
    docker :run,
      ("-it" if interactive),
      "--rm",
      *env_args,
      *volume_args,
      image,
      *command
  end

  def execute_in_existing_container_over_ssh(*command)
    run_over_ssh execute_in_existing_container(*command, interactive: true).join(" ")
  end

  def execute_in_new_container_over_ssh(*command)
    run_over_ssh execute_in_new_container(*command, interactive: true).join(" ")
  end

  def run_over_ssh(command)
    super command, host: host
  end


  def ensure_local_file_present(local_file)
    if !local_file.is_a?(StringIO) && !Pathname.new(local_file).exist?
      raise "Missing file: #{local_file}"
    end
  end

  def make_directory_for(remote_file)
    make_directory Pathname.new(remote_file).dirname.to_s
  end

  def make_directory(path)
    [ :mkdir, "-p", path ]
  end

  def remove_service_directory
    [ :rm, "-rf", service_name ]
  end

  def remove_container
    docker :container, :prune, "-f", *service_filter
  end

  def remove_image
    docker :image, :prune, "-a", "-f", *service_filter
  end

  private
    def service_filter
      [ "--filter", "label=service=#{service_name}" ]
    end
end
