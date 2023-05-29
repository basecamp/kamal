require "active_support/duration"
require "active_support/core_ext/numeric/time"

class Mrsk::Commands::Prune < Mrsk::Commands::Base
  def images
    pipe \
      docker(:image, :ls, *service_filter, "--format", "'{{.Repository}}:{{.Tag}}'"),
      "grep -v -w \"#{active_image_list}\"",
      "while read tag; do docker rmi $tag; done"
  end

  def containers(keep_last: 5)
    pipe \
      docker(:ps, "-q", "-a", *service_filter, *stopped_containers_filters),
      "tail -n +#{keep_last + 1}",
      "while read container_id; do docker rm $container_id; done"
  end

  private
    def stopped_containers_filters
      [ "created", "exited", "dead" ].flat_map { |status| ["--filter", "status=#{status}"] }
    end

    def active_image_list
      "$(docker container ls -a --format '{{.Image}}\\|' --filter label=service=#{config.service} | tr -d '\\n')#{config.latest_image}"
    end

    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end
end
