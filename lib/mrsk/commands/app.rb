class Mrsk::Commands::App
  attr_accessor :config

  def initialize(config)
    @config = config
  end

  def push
    # TODO: Run 'docker buildx create --use' when needed
    "docker buildx build --push --platform=linux/amd64,linux/arm64 -t #{config.image_with_version} ."
  end

  def pull
    "docker pull #{config.image_with_version}"
  end

  def start
    "docker run -d --rm --name #{config.service_with_version} #{config.envs} #{config.labels} #{config.image_with_version}"
  end

  def stop
    "docker ps -q --filter label=service=#{config.service} | xargs docker stop"
  end

  def info
    "docker ps --filter label=service=#{config.service}"
  end
end
