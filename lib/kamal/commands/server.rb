class Kamal::Commands::Server < Kamal::Commands::Base
  def ensure_service_directory
    [ :mkdir, "-p", config.service_directory ]
  end
end
