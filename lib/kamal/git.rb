module Kamal::Git
  extend self

  def used?
    git? || fossil?
  end

  def user_name
    if git?
      `git config user.name`.strip
    elsif fossil?
      `fossil user default 2>/dev/null`.strip
    else
      ""
    end
  end

  def email
    if git?
      `git config user.email`.strip
    elsif fossil?
      `fossil user default 2>/dev/null`.strip
    else
      ""
    end
  end

  def revision
    if git?
      `git rev-parse HEAD`.strip
    elsif fossil?
      `fossil info`.match(/^checkout:\s+(\S+)/)&.captures&.first.to_s
    else
      ""
    end
  end

  def uncommitted_changes
    if git?
      `git status --porcelain`.strip
    elsif fossil?
      `fossil changes`.strip
    else
      ""
    end
  end

  def root
    if git?
      `git rev-parse --show-toplevel`.strip
    elsif fossil?
      `fossil info`.match(/^local-root:\s+(.+)/)&.captures&.first.to_s.chomp("/").strip
    else
      Dir.pwd
    end
  end

  # returns an array of relative path names of files with uncommitted changes
  def uncommitted_files
    if git?
      `git ls-files --modified`.lines.map(&:strip)
    elsif fossil?
      `fossil changes --classify`.lines.map { |l| l.split(/\s+/, 2).last&.strip }.compact
    else
      []
    end
  end

  # returns an array of relative path names of untracked files, including gitignored files
  def untracked_files
    if git?
      `git ls-files --others`.lines.map(&:strip)
    elsif fossil?
      `fossil extras`.lines.map(&:strip)
    else
      []
    end
  end

  def git?
    @git ||= system("git rev-parse --git-dir > /dev/null 2>&1")
  end

  def fossil?
    @fossil ||= File.exist?(".fslckout") || File.exist?("_FOSSIL_")
  end
end
