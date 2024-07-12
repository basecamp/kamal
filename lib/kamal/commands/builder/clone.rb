module Kamal::Commands::Builder::Clone
  extend ActiveSupport::Concern

  included do
    delegate :clone_directory, :build_directory, to: :"config.builder"
  end

  def clone
    git :clone, Kamal::Git.root, path: clone_directory
  end

  def clone_reset_steps
    [
      git(:remote, "set-url", :origin, Kamal::Git.root, path: build_directory),
      git(:fetch, :origin, path: build_directory),
      git(:reset, "--hard", Kamal::Git.revision, path: build_directory),
      git(:clean, "-fdx", path: build_directory)
    ]
  end

  def clone_status
    git :status, "--porcelain", path: build_directory
  end

  def clone_revision
    git :"rev-parse", :HEAD, path: build_directory
  end
end
