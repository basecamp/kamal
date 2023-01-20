require "mrsk/commands/base"

class Mrsk::Commands::App < Mrsk::Commands::Base
  def run(role: :web)
    role = config.role(role)

    docker :run,
      "-d",
      "--restart unless-stopped",
      "--name", config.service_with_version,
      *rails_master_key_arg,
      *role.env_args,
      *role.label_args,
      config.absolute_image,
      role.cmd
  end

  def start(version: config.version)
    docker :start, "#{config.service}-#{version}"
  end

  def current_container_id
    docker :ps, "-q", service_filter
  end

  def stop
    pipe current_container_id, "xargs docker stop"
  end

  def info
    docker :ps, *service_filter
  end

  def logs(lines: 1000, grep: nil)
    pipe \
      current_container_id,
      "xargs docker logs -n #{lines} -t",
      ("grep #{grep}" if grep)
  end

  def exec(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      *rails_master_key_arg,
      *config.env_args,
      config.service_with_version,
      *command
  end

  def run_exec(*command)
    docker :run,
      "--rm",
      *rails_master_key_arg,
      *config.env_args,
      config.absolute_image,
      *command
  end

  def console(host: config.primary_host)
    "ssh -t #{config.ssh_user}@#{host} '#{exec("bin/rails", "c", interactive: true).join(" ")}'"
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
      [ "-e", redact("RAILS_MASTER_KEY=#{config.master_key}") ]
    end
end
