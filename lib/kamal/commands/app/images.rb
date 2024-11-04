module Kamal::Commands::App::Images
  def list_images
    docker :image, :ls, config.repository
  end

  def remove_images
    docker :image, :prune, "--all", "--force", *image_filter_args
  end

  def tag_latest_image
    docker :tag, config.absolute_image, config.latest_image
  end
end
