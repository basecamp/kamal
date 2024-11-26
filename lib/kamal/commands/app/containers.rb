module Kamal::Commands::App::Containers
  DOCKER_HEALTH_LOG_FORMAT    = "'{{json .State.Health}}'"

  def list_containers
    docker :container, :ls, "--all", *container_filter_args
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
    docker :container, :prune, "--force", *container_filter_args
  end

  def container_health_log(version:)
    pipe \
      container_id_for(container_name: container_name(version)),
      xargs(docker(:inspect, "--format", DOCKER_HEALTH_LOG_FORMAT))
  end
end
