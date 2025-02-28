require "tempfile"
require "open3"

module Kamal::Docker
  extend self
  BUILD_CHECK_TAG = "kamal-local-build-check"

  def included_files
    Tempfile.create do |dockerfile|
      dockerfile.write(<<~DOCKERFILE)
        FROM busybox
        COPY . app
        WORKDIR app
        CMD find . -type f | sed "s|^\./||"
      DOCKERFILE
      dockerfile.close

      cmd = "docker buildx build -t=#{BUILD_CHECK_TAG} -f=#{dockerfile.path} ."
      system(cmd) || raise("failed to build check image")
    end

    cmd = "docker run --rm #{BUILD_CHECK_TAG}"
    out, err, status = Open3.capture3(cmd)
    unless status
      raise "failed to run check image:\n#{err}"
    end

    out.lines.map(&:strip)
  end
end
