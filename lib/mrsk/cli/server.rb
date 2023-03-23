class Mrsk::Cli::Server < Mrsk::Cli::Base
  desc "bootstrap", "Ensure curl and Docker are installed on servers"
  def bootstrap
    with_lock do
      on(MRSK.hosts + MRSK.accessory_hosts) do
        dependencies_to_install = Array.new.tap do |dependencies|
          dependencies << "curl" unless execute "which curl", raise_on_non_zero_exit: false
          dependencies << "docker.io" unless execute "which docker", raise_on_non_zero_exit: false
        end

        if dependencies_to_install.any?
          execute "apt-get update -y && apt-get install #{dependencies_to_install.join(" ")} -y"
        end
      end
    end
  end
end
