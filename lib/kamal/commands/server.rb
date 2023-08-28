class Kamal::Commands::Server < Kamal::Commands::Base
  def ensure_run_directory
    make_directory config.run_directory
  end
end
