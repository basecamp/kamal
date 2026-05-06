class Kamal::Secrets::Adapters::Dashlane < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      unless logged_in?(account)
        system("dcli sync 2> /dev/null")
        raise RuntimeError, "Failed to login to or unlock Dashlane" unless $?.success?
      end
    end

    def logged_in?(account)
      status = <<~STATUS
      Logged in: yes
      Login: #{account}
      Locked: no
      STATUS
      `dcli status 2> /dev/null` == status
    end

    def fetch_secrets(secrets, from:, account:, session:)
      shell_secrets_string = secrets.map(&:shellescape).join(" ")
      dashlane_passwords = JSON.parse(`dcli password #{shell_secrets_string} -o json`)
      dashlane_secrets = JSON.parse(`dcli secret #{shell_secrets_string} -o json`)

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
