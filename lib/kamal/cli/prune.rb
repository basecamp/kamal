class Kamal::Cli::Prune < Kamal::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    mutating do
      containers
      images
    end
  end

  desc "images", "Prune unused images"
  def images
    mutating do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pruned images"), verbosity: :debug
        execute *KAMAL.prune.dangling_images
        execute *KAMAL.prune.tagged_images
      end
    end
  end

  desc "containers", "Prune all stopped containers, except the last 5"
  def containers
    mutating do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pruned containers"), verbosity: :debug
        execute *KAMAL.prune.app_containers
        execute *KAMAL.prune.healthcheck_containers
      end
    end
  end
end
