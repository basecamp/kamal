class Kamal::Commands::Proxy < Kamal::Commands::Base
  delegate :argumentize, :optionize, to: Kamal::Utils

  def run
    docker :run,
      "--name", container_name,
      "--network", "kamal",
      "--detach",
      "--restart", "unless-stopped",
      "--volume", "kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy",
      "\$\(#{get_boot_options.join(" ")}\)",
      config.proxy_image
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
    docker :container, :prune, "--force", "--filter", "label=org.opencontainers.image.title=kamal-proxy"
  end

  def remove_image
    docker :image, :prune, "--all", "--force", "--filter", "label=org.opencontainers.image.title=kamal-proxy"
  end

  def cleanup_traefik
    chain \
      docker(:container, :stop, "traefik"),
      combine(
        docker(:container, :prune, "--force", "--filter", "label=org.opencontainers.image.title=Traefik"),
        docker(:image, :prune, "--all", "--force", "--filter", "label=org.opencontainers.image.title=Traefik")
      )
  end

  def ensure_proxy_directory
    make_directory config.proxy_directory
  end

  def remove_proxy_directory
    remove_directory config.proxy_directory
  end

  def get_boot_options
    combine [ :cat, config.proxy_options_file ], [ :echo, "\"#{config.proxy_options_default.join(" ")}\"" ], by: "||"
  end

  def reset_boot_options
    remove_file config.proxy_options_file
  end

  private
    def container_name
      config.proxy_container_name
    end
end
