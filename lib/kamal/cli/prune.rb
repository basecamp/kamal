class Kamal::Cli::Prune < Kamal::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    with_lock do
      containers
      images
    end
  end

  desc "images", "Prune unused images"
  def images
    with_lock do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pruned images"), verbosity: :debug
        execute *KAMAL.prune.dangling_images
        execute *KAMAL.prune.tagged_images
      end
    end
  end

  desc "containers", "Prune all stopped containers, except the last n (default 5)"
  option :retain, type: :numeric, default: nil, desc: "Number of containers to retain"
  def containers
    retain = options.fetch(:retain, KAMAL.config.retain_containers)
    raise "retain must be at least 1" if retain < 1

    with_lock do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pruned containers"), verbosity: :debug
        execute *KAMAL.prune.app_containers(retain: retain)
      end
    end
  end
end
