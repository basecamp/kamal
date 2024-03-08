class Kamal::Commands::Proxy < Kamal::Commands::Base
  CONTAINER_PORT = 80

  delegate :argumentize, :optionize, to: Kamal::Utils

  DEFAULT_IMAGE = "dmcbreen/mproxy:latest"

  def run
    docker :run,
      "--name", container_name,
      "--detach",
      "--restart", "unless-stopped",
      *publish_args,
      "--volume", "/var/run/docker.sock:/var/run/docker.sock",
      *config.logging_args,
      *label_args,
      *docker_options_args,
      image,
      *cmd_option_args
  end

  def start
    docker :container, :start, container_name
  end

  def stop
    docker :container, :stop, container_name
  end

  def start_or_run
    combine start, run, by: "||"
  end

  def deploy(version)
    docker :exec, container_name, :mproxy, :deploy, version
  end

  def remove(version)
    docker :exec, container_name, :mproxy, :remove, version
  end

  def info
    docker :ps, "--filter", "name=^#{container_name}$"
  end

  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      docker(:logs, container_name, (" --since #{since}" if since), (" --tail #{lines}" if lines), "--timestamps", "2>&1"),
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh pipe(
      docker(:logs, container_name, "--timestamps", "--tail", "10", "--follow", "2>&1"),
      (%(grep "#{grep}") if grep)
    ).join(" "), host: host
  end

  def remove_container
    docker :container, :prune, "--force", "--filter", container_filter
  end

  def remove_image
    docker :image, :prune, "--all", "--force", "--filter", image_filter
  end

  def port
    "#{host_port}:#{CONTAINER_PORT}"
  end

  private
    def container_filter
      "label=org.opencontainers.image.title=mproxy"
    end

    def image_filter
      "label=org.opencontainers.image.title=mproxy"
    end

    def publish_args
      argumentize "--publish", port unless config.proxy["publish"] == false
    end

    def label_args
      argumentize "--label", labels
    end

    def labels
      config.proxy["labels"] || {}
    end

    def image
      config.proxy.fetch("image") { DEFAULT_IMAGE }
    end

    def docker_options_args
      optionize(config.proxy["options"] || {})
    end

    def cmd_option_args
      optionize cmd_args, with: "="
    end

    def cmd_args
      config.proxy["args"] || {}
    end

    def host_port
      config.proxy["host_port"] || CONTAINER_PORT
    end

    def container_name
      "mproxy"
    end
end
