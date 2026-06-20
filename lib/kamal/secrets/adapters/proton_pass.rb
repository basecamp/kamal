class Kamal::Secrets::Adapters::ProtonPass < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private
    def login(account)
      unless loggedin?
        system("pass-cli login")
        raise RuntimeError, "Failed to login to Proton Pass" unless $?.success?
      end
    end

    def loggedin?
      `pass-cli info 2> /dev/null`
      $?.success?
    end

    def fetch_secrets(secrets, from:, account:, session:)
      prefixed_secrets(secrets, from: from).to_h do |secret|
        path = generate_secret_path(secret)
        output = `pass-cli item view #{path.shellescape} --output json 2>&1`.strip
        raise RuntimeError, "Could not read #{path} from Proton Pass" unless $?.success?

        [ secret, output ]
      end
    end

    def generate_secret_path(secret)
      parts = secret.split("/")
      normalized = parts.length == 2 ? "#{secret}/password" : secret
      "pass://#{normalized}"
    end

    def check_dependencies!
      raise RuntimeError, "Proton Pass CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `pass-cli --version 2> /dev/null`
      $?.success?
    end
end
