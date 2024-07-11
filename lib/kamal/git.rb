module Kamal::Git
  extend self

  def used?
    system("git rev-parse")
  end

  def user_name
    `git config user.name`.strip
  end

  def email
    `git config user.email`.strip
  end

  def revision
    `git rev-parse HEAD`.strip
  end

  def uncommitted_changes
    `git status --porcelain`.strip
  end

  def root
    `git rev-parse --show-toplevel`.strip
  end
end
