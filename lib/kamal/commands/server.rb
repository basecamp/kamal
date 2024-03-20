class Kamal::Commands::Server < Kamal::Commands::Base
  def ensure_run_directory
    [ :mkdir, "-p", config.run_directory ]
  end
end
