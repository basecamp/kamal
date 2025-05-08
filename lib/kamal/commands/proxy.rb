class Kamal::Commands::Proxy < Kamal::Commands::Base
  delegate :argumentize, :optionize, to: Kamal::Utils

  def run
    pipe boot_config, xargs(docker_run)
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
      [ :awk, "-F:", "'{print \$NF}'" ]
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
    make_directory config.proxy_boot.host_directory
  end

  def remove_proxy_directory
    remove_directory config.proxy_boot.host_directory
  end

  def ensure_apps_config_directory
    make_directory config.proxy_boot.apps_directory
  end

  def boot_config
    [ :echo, "#{substitute(read_boot_options)} #{substitute(read_image)}:#{substitute(read_image_version)} #{substitute(read_run_command)}" ]
  end

  def read_boot_options
    read_file(config.proxy_boot.options_file, default: config.proxy_boot.default_boot_options.join(" "))
  end

  def read_image
    read_file(config.proxy_boot.image_file, default: config.proxy_boot.image_default)
  end

  def read_image_version
    read_file(config.proxy_boot.image_version_file, default: Kamal::Configuration::Proxy::Boot::MINIMUM_VERSION)
  end

  def read_run_command
    read_file(config.proxy_boot.run_command_file)
  end

  def reset_boot_options
    remove_file config.proxy_boot.options_file
  end

  def reset_image
    remove_file config.proxy_boot.image_file
  end

  def reset_image_version
    remove_file config.proxy_boot.image_version_file
  end

  def reset_run_command
    remove_file config.proxy_boot.run_command_file
  end

  private
    def container_name
      config.proxy_boot.container_name
    end

    def read_file(file, default: nil)
      combine [ :cat, file, "2>", "/dev/null" ], [ :echo, "\"#{default}\"" ], by: "||"
    end

    def docker_run
      docker \
        :run,
        "--name", container_name,
        "--network", "kamal",
        "--detach",
        "--restart", "unless-stopped",
        "--volume", "kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy",
        *config.proxy_boot.apps_volume.docker_args
    end
end
