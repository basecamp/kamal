module Kamal::Commands::App::Images
  def list_images
    docker :image, :ls, config.repository
  end

  def remove_images
    docker :image, :prune, "--all", "--force", *filter_args
  end

  def tag_current_image_as_latest
    docker :tag, config.absolute_image, config.latest_image
  end
end
