class Kamal::Secrets::Adapters::Doppler < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      unless loggedin?
        raise RuntimeError, "Doppler CLI not logged in and no DOPPLER_TOKEN found in environment"
      end
    end

    def loggedin?
      `doppler me 2> /dev/null`
      $?.success?
    end

    def fetch_secrets(secrets, account:, session:)
      if secrets.empty?
        raise RuntimeError, "No secrets were fetched. Please specify which secrets to fetch or use 'all' to fetch all secrets."
      end

      project_and_config_flags = ""
      unless service_token_set?
        project, config, _ = secrets.first.split("/")

        unless project && config
          raise RuntimeError, "You must pass the Doppler project and config in using --from PROJECT/CONFIG"
        end

        project_and_config_flags = " -p #{project.shellescape} -c #{config.shellescape}"
      end

      secret_names = secrets.collect{|s| s.split("/").last}

      if secret_names.first.downcase == "all"
        raw_secrets_json = `doppler secrets download --no-file --json#{project_and_config_flags}`
      else
        raw_secrets_json = `doppler secrets get --json#{project_and_config_flags} #{secret_names.map(&:shellescape).join(" ")}`
      end
      raise RuntimeError, "Could not read #{secrets} from Doppler" unless $?.success?

      secrets_json = JSON.parse(raw_secrets_json)
      {}.tap do |results|
        secrets_json.each do |k, v|
          results[k] = v["computed"] || v
        end
      end
    end

    def service_token_set?
      ENV["DOPPLER_TOKEN"] && ENV["DOPPLER_TOKEN"][0,5] == "dp.st"
    end

    def check_dependencies!
      raise RuntimeError, "Doppler CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `doppler --version 2> /dev/null`
      $?.success?
    end
end
