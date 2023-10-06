module Kamal::Git
  extend self

  def used?
    system("git rev-parse")
  end

  def user_name
    `git config user.name`.strip
  end

  def revision
    `git describe --always`.strip
  end

  def uncommitted_changes
    `git status --porcelain`.strip
  end
end
