# FIXME: Use Shellwords.join
class Mrsk::Commands::App < Mrsk::Commands::Base
  def push
    # TODO: Run 'docker buildx create --use' when needed
    "docker buildx build --push --platform=linux/amd64,linux/arm64 -t #{config.absolute_image} ."
  end

  def pull
    "docker pull #{config.absolute_image}"
  end

  def run
    "docker run -d --restart unless-stopped --name #{config.service_with_version} #{config.envs} #{config.labels} #{config.absolute_image}"
  end

  def start
    "docker start #{config.service_with_version}"
  end

  def stop
    "docker ps -q --filter label=service=#{config.service} | xargs docker stop"
  end

  def info
    "docker ps --filter label=service=#{config.service}"
  end

  def remove_containers
    "docker container prune -f #{service_filter}"
  end

  def remove_images
    "docker image prune -a -f #{service_filter}"
  end

  private
    def service_filter
      "--filter label=service=#{config.service}"
    end
end
