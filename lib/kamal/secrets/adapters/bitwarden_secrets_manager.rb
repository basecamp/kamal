class Kamal::Secrets::Adapters::BitwardenSecretsManager < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private
    LIST_ALL_SELECTOR = "all"
    LIST_ALL_FROM_PROJECT_SUFFIX = "/all"
    LIST_COMMAND = "secret list"
    GET_COMMAND = "secret get"

    def fetch_secrets(secrets, from:, account:, session:)
      raise RuntimeError, "You must specify what to retrieve from Bitwarden Secrets Manager" if secrets.length == 0

      secrets = prefixed_secrets(secrets, from: from)
      command, project = extract_command_and_project(secrets)

      {}.tap do |results|
        if command.nil?
          secrets.each do |secret_uuid|
            item_json = run_command("#{GET_COMMAND} #{secret_uuid.shellescape}")
            raise RuntimeError, "Could not read #{secret_uuid} from Bitwarden Secrets Manager" unless $?.success?
            item_json = JSON.parse(item_json)
            results[item_json["key"]] = item_json["value"]
          end
        else
          items_json = run_command(command)
          raise RuntimeError, "Could not read secrets from Bitwarden Secrets Manager" unless $?.success?

          JSON.parse(items_json).each do |item_json|
            results[item_json["key"]] = item_json["value"]
          end
        end
      end
    end

    def extract_command_and_project(secrets)
      if secrets.length == 1
        if secrets[0] == LIST_ALL_SELECTOR
          [ LIST_COMMAND, nil ]
        elsif secrets[0].end_with?(LIST_ALL_FROM_PROJECT_SUFFIX)
          project = secrets[0].split(LIST_ALL_FROM_PROJECT_SUFFIX).first
          [ "#{LIST_COMMAND} #{project.shellescape}", project ]
        end
      end
    end

    def run_command(command, session: nil)
      full_command = [ "bws", command ].join(" ")
      `#{full_command}`
    end

    def login(account)
      run_command("project list")
      raise RuntimeError, "Could not authenticate to Bitwarden Secrets Manager. Did you set a valid access token?" unless $?.success?
    end

    def check_dependencies!
      raise RuntimeError, "Bitwarden Secrets Manager CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `bws --version 2> /dev/null`
      $?.success?
    end
end
