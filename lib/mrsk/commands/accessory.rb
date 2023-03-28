class Mrsk::Commands::Accessory < Mrsk::Commands::Base
  attr_reader :accessory_config
  delegate :service_name, :image, :hosts, :port, :files, :directories, :cmd,
           :publish_args, :env_args, :volume_args, :label_args, :option_args, to: :accessory_config

  def initialize(config, name:)
    super(config)
    @accessory_config = config.accessory(name)
  end

  def run
    docker :run,
      "--name", service_name,
      "--detach",
      "--restart", "unless-stopped",
      *config.logging_args,
      *publish_args,
      *env_args,
      *volume_args,
      *label_args,
      *option_args,
      image,
      cmd
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
      docker(:logs, service_name, (" --since #{since}" if since), (" --tail #{lines}" if lines), "--timestamps", "2>&1"),
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(grep: nil)
    run_over_ssh \
      pipe \
        docker(:logs, service_name, "--timestamps", "--tail", "10", "--follow", "2>&1"),
        (%(grep "#{grep}") if grep)
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
    run_over_ssh execute_in_existing_container(*command, interactive: true)
  end

  def execute_in_new_container_over_ssh(*command)
    run_over_ssh execute_in_new_container(*command, interactive: true)
  end

  def run_over_ssh(command)
    super command, host: hosts.first
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
    docker :container, :prune, "--force", *service_filter
  end

  def remove_image
    docker :image, :rm, "--force", image
  end

  private
    def service_filter
      [ "--filter", "label=service=#{service_name}" ]
    end
end
