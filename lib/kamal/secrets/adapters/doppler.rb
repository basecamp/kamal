class Kamal::Secrets::Adapters::Doppler < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private
    def login(*)
      unless loggedin?
        `doppler login -y`
        raise RuntimeError, "Failed to login to Doppler" unless $?.success?
      end
    end

    def loggedin?
      `doppler me --json 2> /dev/null`
      $?.success?
    end

    def fetch_secrets(secrets, **)
      project_and_config_flags = ""
      unless service_token_set?
        project, config, _ = secrets.first.split("/")

        unless project && config
          raise RuntimeError, "Missing project or config from '--from=project/config' option"
        end

        project_and_config_flags = "-p #{project.shellescape} -c #{config.shellescape}"
      end

      secret_names = secrets.collect { |s| s.split("/").last }

      items = `doppler secrets get #{secret_names.map(&:shellescape).join(" ")} --json #{project_and_config_flags}`
      raise RuntimeError, "Could not read #{secrets} from Doppler" unless $?.success?

      items = JSON.parse(items)

      items.transform_values { |value| value["computed"] }
    end

    def service_token_set?
      ENV["DOPPLER_TOKEN"] && ENV["DOPPLER_TOKEN"][0, 5] == "dp.st"
    end

    def check_dependencies!
      raise RuntimeError, "Doppler CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `doppler --version 2> /dev/null`
      $?.success?
    end
end
