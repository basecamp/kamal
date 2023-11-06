class Kamal::Commands::Curl < Kamal::Commands::Base
    # Install Docker using the https://github.com/docker/docker-install convenience script.
    def install
      [ "apt-get", "--assume-yes install", "curl" ]
    end
  
    # Checks the curl client version. Fails if curl is not installed.
    def installed?
      curl "--version"
    end

    # 
    def is_installable_with_apt?
      [ cat, "/etc/debian_version" ]
    end

  end
  