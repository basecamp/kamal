class Kamal::Commands::App < Kamal::Commands::Base
  ACTIVE_DOCKER_STATUSES = [ :running, :restarting ]

  attr_reader :role, :role_config

  def initialize(config, role: nil)
    super(config)
    @role = role
    @role_config = config.role(self.role)
  end

  def run(hostname: nil)
    docker :run,
      "--detach",
      "--restart unless-stopped",
      "--name", container_name,
      *(["--hostname", hostname] if hostname),
      "-e", "KAMAL_CONTAINER_NAME=\"#{container_name}\"",
      *role_config.env_args,
      *role_config.health_check_args,
      *config.logging_args,
      *config.volume_args,
      *role_config.asset_volume_args,
      *role_config.label_args,
      *role_config.option_args,
      config.absolute_image,
      role_config.cmd
  end

  def start
    docker :start, container_name
  end

  def status(version:)
    pipe container_id_for_version(version), xargs(docker(:inspect, "--format", DOCKER_HEALTH_STATUS_FORMAT))
  end

  def stop(version: nil)
    pipe \
      version ? container_id_for_version(version) : current_running_container_id,
      xargs(config.stop_wait_time ? docker(:stop, "-t", config.stop_wait_time) : docker(:stop))
  end

  def info
    docker :ps, *filter_args
  end


  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      current_running_container_id,
      "xargs docker logs#{" --since #{since}" if since}#{" --tail #{lines}" if lines} 2>&1",
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, grep: nil)
    run_over_ssh \
      pipe(
        current_running_container_id,
        "xargs docker logs --timestamps --tail 10 --follow 2>&1",
        (%(grep "#{grep}") if grep)
      ),
      host: host
  end


  def execute_in_existing_container(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      container_name,
      *command
  end

  def execute_in_new_container(*command, interactive: false)
    docker :run,
      ("-it" if interactive),
      "--rm",
      *role_config&.env_args,
      *config.volume_args,
      *role_config&.option_args,
      config.absolute_image,
      *command
  end

  def execute_in_existing_container_over_ssh(*command, host:)
    run_over_ssh execute_in_existing_container(*command, interactive: true), host: host
  end

  def execute_in_new_container_over_ssh(*command, host:)
    run_over_ssh execute_in_new_container(*command, interactive: true), host: host
  end


  def current_running_container_id
    docker :ps, "--quiet", *filter_args(statuses: ACTIVE_DOCKER_STATUSES), "--latest"
  end

  def container_id_for_version(version, only_running: false)
    container_id_for(container_name: container_name(version), only_running: only_running)
  end

  def current_running_version
    list_versions("--latest", statuses: ACTIVE_DOCKER_STATUSES)
  end

  def list_versions(*docker_args, statuses: nil)
    pipe \
      docker(:ps, *filter_args(statuses: statuses), *docker_args, "--format", '"{{.Names}}"'),
      %(while read line; do echo ${line##{role_config.container_prefix}-}; done) # Extract SHA from "service-role-dest-SHA"
  end

  def list_containers
    docker :container, :ls, "--all", *filter_args
  end

  def list_container_names
    [ *list_containers, "--format", "'{{ .Names }}'" ]
  end

  def remove_container(version:)
    pipe \
      container_id_for(container_name: container_name(version)),
      xargs(docker(:container, :rm))
  end

  def rename_container(version:, new_version:)
    docker :rename, container_name(version), container_name(new_version)
  end

  def remove_containers
    docker :container, :prune, "--force", *filter_args
  end

  def list_images
    docker :image, :ls, config.repository
  end

  def remove_images
    docker :image, :prune, "--all", "--force", *filter_args
  end

  def tag_current_as_latest
    docker :tag, config.absolute_image, config.latest_image
  end

  def make_env_directory
    make_directory role_config.host_env_directory
  end

  def remove_env_file
    [:rm, "-f", role_config.host_env_file_path]
  end

  def cord(version:)
    pipe \
      docker(:inspect, "-f '{{ range .Mounts }}{{printf \"%s %s\\n\" .Source .Destination}}{{ end }}'", container_name(version)),
      [:awk, "'$2 == \"#{role_config.cord_volume.container_path}\" {print $1}'"]
  end

  def tie_cord(cord)
    create_empty_file(cord)
  end

  def cut_cord(cord)
    remove_directory(cord)
  end

  def extract_assets
    asset_container = "#{role_config.container_prefix}-assets"

    combine \
      make_directory(role_config.asset_extracted_path),
      [*docker(:stop, "-t 1", asset_container, "2> /dev/null"), "|| true"],
      docker(:run, "--name", asset_container, "--detach", "--rm", config.latest_image, "sleep 1000000"),
      docker(:cp, "-L", "#{asset_container}:#{role_config.asset_path}/.", role_config.asset_extracted_path),
      docker(:stop, "-t 1", asset_container),
      by: "&&"
  end

  def sync_asset_volumes(old_version: nil)
    new_extracted_path, new_volume_path = role_config.asset_extracted_path(config.version), role_config.asset_volume.host_path
    if old_version.present?
      old_extracted_path, old_volume_path = role_config.asset_extracted_path(old_version), role_config.asset_volume(old_version).host_path
    end

    commands = [make_directory(new_volume_path), copy_contents(new_extracted_path, new_volume_path)]

    if old_version.present?
      commands << copy_contents(new_extracted_path, old_volume_path, continue_on_error: true)
      commands << copy_contents(old_extracted_path, new_volume_path, continue_on_error: true)
    end

    chain *commands
  end

  def clean_up_assets
    chain \
      find_and_remove_older_siblings(role_config.asset_extracted_path),
      find_and_remove_older_siblings(role_config.asset_volume_path)
  end

  private
    def container_name(version = nil)
      [ role_config.container_prefix, version || config.version ].compact.join("-")
    end

    def filter_args(statuses: nil)
      argumentize "--filter", filters(statuses: statuses)
    end

    def service_role_dest
      [config.service, role, config.destination].compact.join("-")
    end

    def filters(statuses: nil)
      [ "label=service=#{config.service}" ].tap do |filters|
        filters << "label=destination=#{config.destination}" if config.destination
        filters << "label=role=#{role}" if role
        statuses&.each do |status|
          filters << "status=#{status}"
        end
      end
    end

    def find_and_remove_older_siblings(path)
      [
        :find,
        Pathname.new(path).dirname.to_s,
        "-maxdepth 1",
        "-name", "'#{role_config.container_prefix}-*'",
        "!", "-name", Pathname.new(path).basename.to_s,
        "-exec rm -rf \"{}\" +"
      ]
    end

    def copy_contents(source, destination, continue_on_error: false)
      [ :cp, "-rnT", "#{source}", destination, *("|| true" if continue_on_error)]
    end
end
