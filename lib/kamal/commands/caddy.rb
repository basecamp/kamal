class Kamal::Commands::Caddy < Kamal::Commands::Base
  delegate :argumentize, :optionize, to: Kamal::Utils

  CADDY_IMAGE = "caddy:2.8-alpine"
  CADDY_PATH = "/etc/caddy"

  def run
    docker :run,
      "--name", container_name,
      "--network", "kamal",
      "--detach",
      "--restart", "unless-stopped",
      "--volume", "kamal-caddy-data:/data",
      "--volume", "#{config.caddy_config_file}:/etc/caddy/Caddyfile",
      CADDY_IMAGE
  end

  def start
    docker :container, :start, container_name
  end

  def stop(name: container_name)
    docker :container, :stop, name
  end

  def start_or_run
    combine start, run, by: "||"
  end

  def info
    docker :ps, "--filter", "name=^#{container_name}$"
  end

  def version
    pipe \
      docker(:inspect, container_name, "--format '{{.Config.Image}}'"),
      [ :cut, "-d:", "-f2" ]
  end

  def logs(timestamps: true, since: nil, lines: nil, grep: nil, grep_options: nil)
    pipe \
      docker(:logs, container_name, ("--since #{since}" if since), ("--tail #{lines}" if lines), ("--timestamps" if timestamps), "2>&1"),
      ("grep '#{grep}'#{" #{grep_options}" if grep_options}" if grep)
  end

  def follow_logs(host:, timestamps: true, grep: nil, grep_options: nil)
    run_over_ssh pipe(
      docker(:logs, container_name, ("--timestamps" if timestamps), "--tail", "10", "--follow", "2>&1"),
      (%(grep "#{grep}"#{" #{grep_options}" if grep_options}) if grep)
    ).join(" "), host: host
  end

  def remove_container
    docker :container, :prune, "--force", "--filter", "label=org.opencontainers.image.title=kamal-caddy"
  end

  def remove_image
    docker :image, :prune, "--all", "--force", "--filter", "label=org.opencontainers.image.title=kamal-caddy"
  end

  def ensure_caddy_directory
    make_directory CADDY_PATH
  end

  def remove_caddy_directory
    remove_directory CADDY_PATH
  end

  private
    def container_name
      "kamal-caddy"
    end
end
