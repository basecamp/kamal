class Kamal::Commands::Traefik < Kamal::Commands::Base
  delegate :argumentize, :optionize, to: Kamal::Utils
  delegate :port, :publish?, :labels, :env, :image, :options, :args, to: :"config.traefik"

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
    any start, run
  end

  def info
    docker :ps, "--filter", "name=^traefik$"
  end

  def logs(since: nil, lines: nil, grep: nil, grep_options: nil)
    pipe \
      docker(:logs, "traefik", (" --since #{since}" if since), (" --tail #{lines}" if lines), "--timestamps", "2>&1"),
      ("grep '#{grep}'#{" #{grep_options}" if grep_options}" if grep)
  end

  def follow_logs(host:, grep: nil, grep_options: nil)
    run_over_ssh pipe(
      docker(:logs, "traefik", "--timestamps", "--tail", "10", "--follow", "2>&1"),
      (%(grep "#{grep}"#{" #{grep_options}" if grep_options}) if grep)
    ).join(" "), host: host
  end

  def remove_container
    docker :container, :prune, "--force", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def remove_image
    docker :image, :prune, "--all", "--force", "--filter", "label=org.opencontainers.image.title=Traefik"
  end

  def make_env_directory
    make_directory(env.secrets_directory)
  end

  def remove_env_file
    [ :rm, "-f", env.secrets_file ]
  end

  private
    def publish_args
      argumentize "--publish", port if publish?
    end

    def label_args
      argumentize "--label", labels
    end

    def env_args
      env.args
    end

    def docker_options_args
      optionize(options)
    end

    def cmd_option_args
      optionize args, with: "="
    end
end
