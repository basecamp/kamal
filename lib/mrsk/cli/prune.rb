require "mrsk/cli/base"
require 'mrsk/cli/helpers'

class Mrsk::Cli::Prune < Mrsk::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    invoke :containers
    invoke :images
  end

  desc "images", "Prune unused images based on keep_releases config"
  def images
    on(MRSK.hosts) do
      result = capture *MRSK.image.list('{{.ID}},{{.CreatedAt}}')
      result_hash = Mrsk::Cli::Helpers::ImageList.captured_image_list_to_hash(result)

      next if result_hash.count <= MRSK.config.keep_releases
      to_be_deleted_images = result_hash.last(result_hash.count - MRSK.config.keep_releases).pluck(:id)

      execute *MRSK.image.rm(to_be_deleted_images)
    end
  end

  desc "containers", "Prune stopped containers based on keep_releases config"
  def containers
    on(MRSK.hosts) do
      keep_container_ids = capture(*MRSK.container.list(format: "{{.ID}}", last: MRSK.config.keep_releases, filter: "status=exited")).split("\n")
      all_container_ids = capture(*MRSK.container.list(format: "{{.ID}}", filter: "status=exited")).split("\n")
      should_be_deleted_container_ids = all_container_ids - keep_container_ids
      next unless should_be_deleted_container_ids.length.positive?

      execute *MRSK.container.rm(all_container_ids - keep_container_ids)
    end
  end
end
