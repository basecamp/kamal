class Kamal::Commands::Traefik::Static < Kamal::Commands::Base
  attr_reader :static_config, :dynamic_config

  def initialize(config, role: nil)
    super(config)
    @static_config = Kamal::Configuration::Traefik::Static.new(config: config)
  end

  def run
    docker :run, static_config.docker_args, static_config.image, static_config.traefik_args
  end

  def start
    docker :container, :start, "traefik"
  end

  def stop
    docker :container, :stop, "traefik"
  end

  def start_or_run
    combine start, run, by: "||"
  end

  def info
    docker :ps, "--filter", "name=^traefik$"
  end

  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      docker(:logs, "traefik", (" --since #{since}" if since), (" --tail #{lines}" if lines), "--timestamps", "2>&1"),
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh pipe(
      docker(:logs, "traefik", "--timestamps", "--tail", "10", "--follow", "2>&1"),
      (%(grep "#{grep}") if grep)
    ).join(" "), host: host
  end

  def remove_container
    docker :container, :prune, "--force", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def remove_image
    docker :image, :prune, "--all", "--force", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def port
    "#{host_port}:#{CONTAINER_PORT}"
  end

  def make_env_directory
    make_directory(static_config.host_env_directory)
  end

  def remove_env_file
    [:rm, "-f", static_config.host_env_file_path]
  end

  def ensure_config_directory
    make_directory(static_config.host_directory)
  end

  def docker_entrypoint_args
    docker :inspect, "-f '{{index .Args 1 }}'", :traefik
  end
end

