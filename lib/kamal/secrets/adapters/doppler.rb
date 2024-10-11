class Kamal::Secrets::Adapters::Doppler < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      unless loggedin?(account)
        `doppler login -y`
        raise RuntimeError, "Failed to login to Doppler" unless $?.success?
      end
    end

    def loggedin?(account)
      `doppler me --json 2> /dev/null`
      $?.success?
    end

    def fetch_secrets(secrets, account:, session:)
      project, config = account.split("/")

      raise RuntimeError, "Missing project or config from --acount=project/config option" unless project && config
      raise RuntimeError, "Using --from option or FOLDER/SECRET is not supported by Doppler" if secrets.any?(/\//)

      items = `doppler secrets get #{secrets.map(&:shellescape).join(" ")} --json -p #{project} -c #{config}`
      raise RuntimeError, "Could not read #{secrets} from Doppler" unless $?.success?

      items = JSON.parse(items)

      items.transform_values { |value| value["computed"] }
    end
end
