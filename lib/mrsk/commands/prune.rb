require "active_support/duration"
require "active_support/core_ext/numeric/time"

class Mrsk::Commands::Prune < Mrsk::Commands::Base
  def images
    docker :image, :prune, "--all", "--force", "--filter", "label=service=#{config.service}", "--filter", "dangling=true"
  end

  def containers(keep_last: 5)
    pipe \
      docker(:ps, "-q", "-a", "--filter", "label=service=#{config.service}", *stopped_containers_filters),
      "tail -n +#{keep_last + 1}",
      "while read container_id; do docker rm $container_id; done"
  end

  private
    def stopped_containers_filters
      [ "created", "exited", "dead" ].flat_map { |status| ["--filter", "status=#{status}"] }
    end
end
