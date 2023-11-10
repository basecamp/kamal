module Kamal::Commands::App::Containers
  def list_containers
    docker :container, :ls, "--all", *filter_args
  end

  def list_active_containers
    docker :container, :ls, *filter_args
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
end
