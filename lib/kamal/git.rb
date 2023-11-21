module Kamal::Git
  extend self

  def used?
    system("git rev-parse")
  end

  def user_name
    `git config user.name`.strip
  end

  def revision
    `git rev-parse HEAD`.strip
  end

  # Attempt to convert a short -> long git sha, or return the original
  def resolve_revision(revision)
    resolved_rev = `git rev-parse -q --verify #{revision}`.strip
    if resolved_rev.empty?
      revision
    else
      resolved_rev
    end
  end

  def uncommitted_changes
    `git status --porcelain`.strip
  end
end
