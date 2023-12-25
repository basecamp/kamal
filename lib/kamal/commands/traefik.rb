class Kamal::Commands::Traefik < Kamal::Commands::Base
  delegate :argumentize, :optionize, to: Kamal::Utils

  DEFAULT_IMAGE = "traefik:v2.9"
  CONTAINER_PORT = 80
  DEFAULT_ARGS = {
    'log.level' => 'DEBUG'
  }
  DEFAULT_LABELS = {
    # These ensure we serve a 502 rather than a 404 if no containers are available
    "traefik.http.routers.catchall.entryPoints" => "http",
    "traefik.http.routers.catchall.rule" => "PathPrefix(`/`)",
    "traefik.http.routers.catchall.service" => "unavailable",
    "traefik.http.routers.catchall.priority" => 1,
    "traefik.http.services.unavailable.loadbalancer.server.port" => "0"
  }

  def run
    docker :run, "--name traefik",
      "--detach",
      "--restart", "unless-stopped",
      *publish_args,
      "--volume", "/var/run/docker.sock:/var/run/docker.sock",
      *env_args,
      *config.logging_args,
      *label_args,
      *docker_options_args,
      image,
      "--providers.docker",
      *cmd_option_args
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

  def env_file
    Kamal::EnvFile.new(config.traefik.fetch("env", {}))
  end

  def host_env_file_path
    File.join host_env_directory, "traefik.env"
  end

  def make_env_directory
    make_directory(host_env_directory)
  end

  def remove_env_file
    [:rm, "-f", host_env_file_path]
  end

  private
    def publish_args
      argumentize "--publish", port unless config.traefik["publish"] == false
    end

    def label_args
      argumentize "--label", labels
    end

    def env_args
      argumentize "--env-file", host_env_file_path
    end

    def host_env_directory
      File.join config.host_env_directory, "traefik"
    end

    def labels
      DEFAULT_LABELS.merge(config.traefik["labels"] || {})
    end

    def image
      config.traefik.fetch("image") { DEFAULT_IMAGE }
    end

    def docker_options_args
      optionize(config.traefik["options"] || {})
    end

    def cmd_option_args
      if args = config.traefik["args"]
        optionize DEFAULT_ARGS.merge(args), with: "="
      else
        optionize DEFAULT_ARGS, with: "="
      end
    end

    def host_port
      config.traefik["host_port"] || CONTAINER_PORT
    end
end
