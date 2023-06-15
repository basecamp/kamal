class Mrsk::Commands::Traefik < Mrsk::Commands::Base
  delegate :argumentize, :argumentize_env_with_secrets, :optionize, to: Mrsk::Utils

  DEFAULT_IMAGE = "traefik:v2.9"
  CONTAINER_PORT = 80
  DEFAULT_ARGS = {
    'log.level' => 'DEBUG'
  }

  def run
    docker :run, "--name traefik",
      "--detach",
      "--restart", "unless-stopped",
      "--publish", port,
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

  private
    def label_args
      argumentize "--label", labels
    end

    def env_args
      env_config = config.traefik["env"] || {}

      if env_config.present?
        argumentize_env_with_secrets(env_config)
      else
        []
      end
    end

    def labels
      config.traefik["labels"] || []
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
