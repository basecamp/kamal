require "tempfile"
require "open3"

module Kamal::Docker
  extend self
  BUILD_CHECK_TAG = "kamal-local-build-check"

  def included_files(builder:)
    commands = nil

    Tempfile.create do |dockerfile|
      dockerfile.write(<<~DOCKERFILE)
        FROM busybox
        COPY . app
        WORKDIR app
        CMD find . -type f | sed "s|^\./||"
      DOCKERFILE
      dockerfile.close

      commands = builder.build_check_commands(dockerfile: dockerfile.path, tag: BUILD_CHECK_TAG)

      system(*commands[:build]) || raise("failed to build check image")
    end

    out, err, status = Open3.capture3(*commands[:run])
    unless status.success?
      raise "failed to run check image:\n#{err}"
    end

    out.lines.map(&:strip)
  end
end
