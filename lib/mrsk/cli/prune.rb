class Mrsk::Cli::Prune < Mrsk::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    mutating do
      containers
      images
    end
  end

  desc "images", "Prune dangling images"
  def images
    mutating do
      on(MRSK.hosts) do
        execute *MRSK.auditor.record("Pruned images"), verbosity: :debug
        execute *MRSK.prune.dangling_images
        execute *MRSK.prune.tagged_images
      end
    end
  end

  desc "containers", "Prune all stopped containers, except the last 5"
  def containers
    mutating do
      on(MRSK.hosts) do
        execute *MRSK.auditor.record("Pruned containers"), verbosity: :debug
        execute *MRSK.prune.containers
      end
    end
  end
end
