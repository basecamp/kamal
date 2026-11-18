require "active_support/duration"
require "active_support/core_ext/numeric/time"

class Kamal::Commands::Prune < Kamal::Commands::Base
  def dangling_images
    docker :image, :prune, "--force", "--filter", "label=service=#{config.service}"
  end

  def tagged_images
    pipe \
      docker(:image, :ls, *service_filter, "--format", "'{{.ID}} {{.Repository}}:{{.Tag}}'"),
      grep("-v -w \"#{active_image_list}\""),
      "while read image tag; do docker rmi $tag; done"
  end

  def app_containers(retain:, protected_ids: [])
    unless protected_ids.all? { |id| id.is_a?(String) && id.match?(/\A[0-9a-f]{64}\z/) }
      raise ArgumentError, "Invalid protected container ID"
    end
    pipe \
      docker(:ps, "-q", "-a", *("--no-trunc" if protected_ids.any?), *service_filter, *destination_filter, *stopped_containers_filters),
      ("grep -F -x -v #{protected_ids.uniq.map { |id| "-e #{id}" }.join(' ')}" if protected_ids.any?),
      "tail -n +#{retain + 1}",
      "while read container_id; do docker rm $container_id; done"
  end

  # Read only the services managed by these app roles. Other services may use
  # non-Docker endpoints. Include readers and rollout targets even when disabled.
  def registered_containers(json, services:)
    descriptions = JSON.parse(json)
    raise ArgumentError, "Invalid proxy service list" unless descriptions.is_a?(Hash)

    services.flat_map do |name|
      description = descriptions.fetch(name)
      raise ArgumentError, "Invalid proxy service" unless description.is_a?(Hash)
      active = description.fetch("targets")
      raise ArgumentError, "Missing active targets" unless active.is_a?(Array) && active.any?
      rollout = description.fetch("rollout", {})
      raise ArgumentError, "Invalid rollout" unless rollout.is_a?(Hash)
      lists = [ active, description.fetch("read_targets", []), rollout.fetch("targets", []), rollout.fetch("read_targets", []) ]
      raise ArgumentError, "Invalid target lists" unless lists.all? { |list| list.is_a?(Array) }
      lists.flatten.map do |target|
        match = target.is_a?(String) && target.match(/\A([a-zA-Z0-9][a-zA-Z0-9_.-]*):[0-9]+\z/)
        raise ArgumentError, "Invalid container target" unless match
        match[1]
      end
    end.uniq
  end

  def inspect_registered_containers(containers)
    docker :inspect, "--format", "'{{.Id}}'", *containers
  end

  private
    def stopped_containers_filters
      [ "created", "exited", "dead" ].flat_map { |status| [ "--filter", "status=#{status}" ] }
    end

    def active_image_list
      # Pull the images that are used by any containers
      # Append repo:<none> - to avoid deleting dangling images that are in use. Unused dangling images are deleted separately
      # Append a repo-agnostic latest pattern - to preserve destination tags that use another repository
      "$(docker container ls -a --format '{{.Image}}\\|' --filter label=service=#{config.service} | tr -d '\\n')#{config.repository}:<none>\\|[^ ]*:latest\\(-[^ ]*\\)\\?$"
    end

    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end

    def destination_filter
      [ "--filter", "label=destination=#{config.destination}" ]
    end
end
