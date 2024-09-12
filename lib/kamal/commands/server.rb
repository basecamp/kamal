class Kamal::Commands::Server < Kamal::Commands::Base
  def ensure_app_directory
    make_directory config.app_directory
  end

  def remove_app_directory
    remove_directory config.app_directory
  end

  def app_directory_count
    pipe \
      [ :ls, config.apps_directory ],
      [ :wc, "-l" ]
  end
end
