require "mrsk/commands/base"
require "mrsk/commands/concerns"

class Mrsk::Commands::App < Mrsk::Commands::Base
  include Mrsk::Commands::Concerns::Executions

  def run(role: :web)
    role = config.role(role)

    docker :run,
      "-d",
      "--restart unless-stopped",
      "--name", service_with_version,
      *rails_master_key_arg,
      *role.env_args,
      *config.volume_args,
      *role.label_args,
      config.absolute_image,
      role.cmd
  end

  def start
    docker :start, service_with_version
  end

  def current_container_id
    docker :ps, "-q", *service_filter
  end

  def stop
    pipe current_container_id, xargs(docker(:stop))
  end

  def info
    docker :ps, *service_filter
  end

  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      current_container_id,
      "xargs docker logs#{" --since #{since}" if since}#{" -n #{lines}" if lines} 2>&1",
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh pipe(
      current_container_id,
      "xargs docker logs -t -n 10 -f 2>&1",
      (%(grep "#{grep}") if grep)
    ).join(" "), host: host
  end

  def container_id_for(container_name:)
    docker :container, :ls, "-a", "-f", "name=#{container_name}", "-q"
  end

  def current_running_version
    # FIXME: Find more graceful way to extract the version from "app-version" than using sed and tail!
    pipe \
      docker(:ps, "--filter", "label=service=#{service_name}", "--format", '"{{.Names}}"'),
      %(sed 's/-/\\n/g'),
      "tail -n 1"
  end

  def most_recent_version_from_available_images
    pipe \
      docker(:image, :ls, "--format", '"{{.Tag}}"', config.repository),
      "head -n 1"
  end

  def list_containers
    docker :container, :ls, "-a", *service_filter
  end

  def remove_container(version:)
    pipe \
      container_id_for(container_name: service_with_version(version)),
      xargs(docker(:container, :rm))
  end

  def remove_containers
    docker :container, :prune, "-f", *service_filter
  end

  def list_images
    docker :image, :ls, config.repository
  end

  def remove_images
    docker :image, :prune, "-a", "-f", *service_filter
  end

  private
    def service_with_version(version = nil)
      if version
        "#{config.service}-#{version}"
      else
        config.service_with_version
      end
    end

    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end

    def rails_master_key_arg
      if master_key = config.master_key
        [ "-e", redact("RAILS_MASTER_KEY=#{master_key}") ]
      else
        []
      end
    end
end
