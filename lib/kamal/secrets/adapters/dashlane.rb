class Kamal::Secrets::Adapters::Dashlane < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private
    def login(account)
      unless logged_in?
        system("dcli sync 2> /dev/null")
        raise RuntimeError, "Failed to login to or unlock Dashlane" unless $?.success?
      end
    end

    def logged_in?
      status = `dcli status 2> /dev/null`
      return false unless $?.success?

      status = status.each_line(chomp: true).with_object({}) do |line, hash|
        key, value = line.split(":").map(&:strip)
        hash[key] = value if key && value
      end

      status["Logged in"] == "yes" && status["Locked"] == "no"
    end

    def fetch_secrets(secrets, from:, account:, session:)
      raise ArgumentError, "Dashlane adapter does not support the --from option" if from.present?

      shell_secrets_string = secrets.map(&:shellescape).join(" ")
      dashlane_passwords = `dcli password #{shell_secrets_string} -o json`
      raise RuntimeError, "Could not read #{secrets} from Dashlane passwords" unless $?.success?
      dashlane_secrets = `dcli secret #{shell_secrets_string} -o json`
      raise RuntimeError, "Could not read #{secrets} from Dashlane secrets" unless $?.success?

      dashlane_passwords = JSON.parse(dashlane_passwords)
      dashlane_secrets = JSON.parse(dashlane_secrets)
      results = {}

      dashlane_passwords.each do |password|
        results[password["title"]] = password["password"]
      end
      dashlane_secrets.each do |secret|
        results[secret["title"]] = secret["content"]
      end

      if (missing_items = secrets - results.keys).any?
        raise RuntimeError, "Could not find #{missing_items.join(", ")} in Dashlane passwords or secrets"
      end

      results
    end

    def check_dependencies!
      raise RuntimeError, "Dashlane CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `dcli --version 2> /dev/null`
      $?.success?
    end
end
