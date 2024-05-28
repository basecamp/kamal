class Kamal::Configuration::Traefik
  DEFAULT_IMAGE = "traefik:v2.10"
  CONTAINER_PORT = 80
  DEFAULT_ARGS = {
    "log.level" => "DEBUG"
  }
  DEFAULT_LABELS = {
    # These ensure we serve a 502 rather than a 404 if no containers are available
    "traefik.http.routers.catchall.entryPoints" => "http",
    "traefik.http.routers.catchall.rule" => "PathPrefix(`/`)",
    "traefik.http.routers.catchall.service" => "unavailable",
    "traefik.http.routers.catchall.priority" => 1,
    "traefik.http.services.unavailable.loadbalancer.server.port" => "0"
  }

  include Kamal::Configuration::Validation

  attr_reader :config, :traefik_config

  def initialize(config:)
    @config = config
    @traefik_config = config.raw_config.traefik || {}
    validate! traefik_config
  end

  def publish?
    traefik_config["publish"] != false
  end

  def labels
    DEFAULT_LABELS.merge(traefik_config["labels"] || {})
  end

  def env
    Kamal::Configuration::Env.new \
      config: traefik_config.fetch("env", {}),
      secrets_file: File.join(config.host_env_directory, "traefik", "traefik.env"),
      context: "traefik/env"
  end

  def host_port
    traefik_config.fetch("host_port", CONTAINER_PORT)
  end

  def options
    traefik_config.fetch("options", {})
  end

  def port
    "#{host_port}:#{CONTAINER_PORT}"
  end

  def args
    DEFAULT_ARGS.merge(traefik_config.fetch("args", {}))
  end

  def image
    traefik_config.fetch("image", DEFAULT_IMAGE)
  end
end
