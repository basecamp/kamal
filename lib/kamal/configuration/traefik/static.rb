class Kamal::Configuration::Traefik::Static
  CONTAINER_PORT = 80
  DEFAULT_IMAGE = "traefik:v2.9"
  CONFIG_DIRECTORY = "/var/run/traefik-config"
  DEFAULT_ARGS = {
    "providers.docker": true, # Obsolete now but required for zero-downtime upgrade from previous versions
    "providers.file.directory" =>  "/var/run/traefik-config",
    "providers.file.watch": true,
    "log.level" => "DEBUG",
  }

  delegate :argumentize, :env_file_with_secrets, :optionize, to: Kamal::Utils

  attr_reader :config, :traefik_config

  def initialize(config:)
    @config = config
    @traefik_config = config.traefik || {}
  end

  def docker_args
    [
      "--name traefik",
      "--detach",
      "--restart", "unless-stopped",
      *publish_args,
      "--volume", "/var/run/docker.sock:/var/run/docker.sock",
      "--volume", "#{host_directory}:#{CONFIG_DIRECTORY}",
      *env_args,
      *config.logging_args,
      *label_args,
      *docker_options_args
    ]
  end

  def image
    traefik_config.fetch("image") { DEFAULT_IMAGE }
  end

  def traefik_args
    optionize DEFAULT_ARGS.merge(traefik_config.fetch("args", {})), with: "="
  end

  def host_directory
    if Pathname.new(config.run_directory).absolute?
      "#{config.run_directory}/traefik-config"
    else
      "$(pwd)/#{config.run_directory}/traefik-config"
    end
  end

  def host_env_file_path
    File.join host_env_directory, "traefik.env"
  end

  def host_env_directory
    File.join config.host_env_directory, "traefik"
  end

  def env_file
    env_file_with_secrets config.traefik.fetch("env", {})
  end

  private
    def host_port
      traefik_config.fetch("host_port", CONTAINER_PORT)
    end

    def publish_args
      argumentize "--publish", "#{host_port}:#{CONTAINER_PORT}" unless traefik_config["publish"] == false
    end

    def env_args
      argumentize "--env-file", host_env_file_path
    end

    def label_args
      argumentize "--label", traefik_config.fetch("labels", [])
    end

    def docker_options_args
      optionize(traefik_config["options"] || {})
    end
end
