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

  def app_containers(retain:)
    pipe \
      docker(:ps, "-q", "-a", *service_filter, *stopped_containers_filters),
      "tail -n +#{retain + 1}",
      "while read container_id; do docker rm $container_id; done"
  end

  private
    def stopped_containers_filters
      [ "created", "exited", "dead" ].flat_map { |status| [ "--filter", "status=#{status}" ] }
    end

    def active_image_list
      # Pull the images that are used by any containers
      # Append repo:latest - to avoid deleting the latest tag
      # Append repo:<none> - to avoid deleting dangling images that are in use. Unused dangling images are deleted separately
      "$(docker container ls -a --format '{{.Image}}\\|' --filter label=service=#{config.service} | tr -d '\\n')#{config.latest_image}\\|#{config.repository}:<none>"
    end

    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end
end
