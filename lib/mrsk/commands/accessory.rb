require "mrsk/commands/base"

class Mrsk::Commands::Accessory < Mrsk::Commands::Base
  attr_reader :accessory_config
  delegate :service_name, :image, :host, :port, :volume_args, :label_args, to: :accessory_config

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
    docker :ps, "--filter", "name=#{service_name}"
  end

  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      docker(:logs, service_name, (" --since #{since}" if since), (" -n #{lines}" if lines), "-t", "2>&1"),
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(grep: nil)
    run_over_ssh pipe(
      docker(:logs, service_name, "-t", "-n", "10", "-f", "2>&1"),
      ("grep '#{grep}'" if grep)
    ).join(" "), host: host
  end

  def remove_container
    docker :container, :prune, "-f", "--filter", "label=name=#{service_name}"
  end

  def remove_image
    docker :image, :prune, "-a", "-f", "--filter", "label=name=#{service_name}"
  end
end
