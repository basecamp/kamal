class Mrsk::Cli::Prune < Mrsk::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    with_lock do
      containers
      images
    end
  end

  desc "images", "Prune dangling images"
  def images
    with_lock do
      on(MRSK.hosts) do
        execute *MRSK.auditor.record("Pruned images"), verbosity: :debug
        execute *MRSK.prune.images
      end
    end
  end

  desc "containers", "Prune all stopped containers, except the last 5"
  def containers
    with_lock do
      on(MRSK.hosts) do
        execute *MRSK.auditor.record("Pruned containers"), verbosity: :debug
        execute *MRSK.prune.containers
      end
    end
  end
end
