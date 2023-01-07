class Mrsk::Commands::Registry < Mrsk::Commands::Base
  def login
    ensure_credentials_present
    "docker login #{config.registry["server"]} -u #{config.registry["username"]} -p #{config.registry["password"]}"
  end

  private
    def ensure_credentials_present
      unless config.registry && config.registry["username"].present? && config.registry["password"].present?
        raise ArgumentError, "You must configure registry/username and registry/password"
      end
    end
end
