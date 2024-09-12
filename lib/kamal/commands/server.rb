class Kamal::Commands::Server < Kamal::Commands::Base
  def ensure_service_directory
    make_directory config.service_directory
  end

  def remove_service_directory
    remove_directory config.service_directory
  end
end
