module Kamal::Commands::App::ErrorPages
  def create_error_pages_directory
    make_directory(config.proxy_boot.error_pages_directory)
  end

  def clean_up_error_pages
    [ :find, config.proxy_boot.error_pages_directory, "-mindepth", "1", "-maxdepth", "1", "!", "-name", KAMAL.config.version, "-exec", "rm", "-rf", "{} +" ]
  end
end
