require "mrsk/commands/base"

class Mrsk::Commands::App < Mrsk::Commands::Base
  def run(role: :web)
    role = config.role(role)

    docker :run,
      "-d",
      "--restart unless-stopped",
      "--name", config.service_with_version,
      "-e", Mrsk::Utils.redact("RAILS_MASTER_KEY=#{config.master_key}"),
      *config.env_args,
      *role.label_args,
      config.absolute_image,
      role.cmd
  end

  def start(version: config.version)
    docker :start, "#{config.service}-#{version}"
  end

  def stop
    [ "docker ps -q #{service_filter.join(" ")} | xargs docker stop" ]
  end

  def info
    docker :ps, *service_filter
  end

  def logs
    [ "docker ps -q #{service_filter.join(" ")} | xargs docker logs -n 100 -t" ]
  end

  def exec(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      "-e", Mrsk::Utils.redact("RAILS_MASTER_KEY=#{config.master_key}"),
      *config.env_args,
      config.service_with_version,
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
end
