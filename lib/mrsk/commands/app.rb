require "mrsk/commands/base"

class Mrsk::Commands::App < Mrsk::Commands::Base
  def run(role: :web)
    role = config.role(role)

    docker :run,
      "-d",
      "--restart unless-stopped",
      "--name", config.service_with_tag,
      *rails_master_key_arg,
      *role.env_args,
      *config.volume_args,
      *role.label_args,
      config.absolute_image,
      role.cmd
  end

  def start(tag: config.tag)
    docker :start, "#{config.service}-#{tag}"
  end

  def current_container_id
    docker :ps, "-q", *service_filter
  end

  def stop
    pipe current_container_id, "xargs docker stop"
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

  def exec(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      config.service_with_tag,
      *command
  end

  def run_exec(*command, interactive: false)
    docker :run,
      ("-it" if interactive),
      "--rm",
      *rails_master_key_arg,
      *config.env_args,
      *config.volume_args,
      config.absolute_image,
      *command
  end

  def exec_over_ssh(*command, host:)
    run_over_ssh run_exec(*command, interactive: true).join(" "), host: host
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh pipe(
      current_container_id,
      "xargs docker logs -t -n 10 -f 2>&1",
      (%(grep "#{grep}") if grep)
    ).join(" "), host: host
  end

  def console(host:)
    exec_over_ssh "bin/rails", "c", host: host
  end

  def bash(host:)
    exec_over_ssh "bash", host: host
  end

  def list_containers
    docker :container, :ls, "-a", *service_filter
  end

  def remove_containers
    docker :container, :prune, "-f", *service_filter
  end

  def remove_images
    docker :image, :prune, "-a", "-f", *service_filter
  end

  private
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
