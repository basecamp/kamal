module Kamal::Commands::Builder::Clone
  def clone
    git :clone, escaped_root, "--recurse-submodules", path: config.builder.clone_directory.shellescape
  end

  def clone_reset_steps
    [
      git(:remote, "set-url", :origin, escaped_root, path: escaped_build_directory),
      git(:fetch, :origin, path: escaped_build_directory),
      git(:reset, "--hard", Kamal::Git.revision, path: escaped_build_directory),
      git(:clean, "-fdx", path: escaped_build_directory),
      git(:submodule, :update, "--init", path: escaped_build_directory)
    ]
  end

  def clone_status
    git :status, "--porcelain", path: escaped_build_directory
  end

  def clone_revision
    git :"rev-parse", :HEAD, path: escaped_build_directory
  end

  def escaped_root
    Kamal::Git.root.shellescape
  end

  def escaped_build_directory
    config.builder.build_directory.shellescape
  end
end
