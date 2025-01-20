class Kamal::Secrets::Adapters::GcpSecretManager < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      # Since only the account option is passed from the cli, we'll use it for both account and service account
      # impersonation.
      #
      # Syntax:
      # ACCOUNT: USER | USER "|" DELEGATION_CHAIN
      # USER: DEFAULT_USER | EMAIL
      # DELEGATION_CHAIN: EMAIL | EMAIL "," DELEGATION_CHAIN
      # EMAIL: <The email address of the user or service account, like "my-user@example.com" >
      # DEFAULT_USER: "default"
      #
      # Some valid examples:
      # - "my-user@example.com" sets the user
      # - "my-user@example.com|my-service-user@example.com" will use my-user and enable service account impersonation as my-service-user
      # - "default" will use the default user and no impersonation
      # - "default|my-service-user@example.com" will use the default user, and enable service account impersonation as my-service-user
      # - "default|my-service-user@example.com,another-service-user@example.com" same as above, but with an impersonation delegation chain

      unless logged_in?
        `gcloud auth login`
        raise RuntimeError, "could not login to gcloud" unless logged_in?
      end

      nil
    end

    def fetch_secrets(secrets, from:, account:, session:)
      user, service_account = parse_account(account)

      {}.tap do |results|
        secrets_with_metadata(prefixed_secrets(secrets, from: from)).each do |secret, (project, secret_name, secret_version)|
          item_name = "#{project}/#{secret_name}"
          results[item_name] = fetch_secret(project, secret_name, secret_version, user, service_account)
          raise RuntimeError, "Could not read #{item_name} from Google Secret Manager" unless $?.success?
        end
      end
    end

    def fetch_secret(project, secret_name, secret_version, user, service_account)
      secret = run_command(
        "secrets versions access #{secret_version.shellescape} --secret=#{secret_name.shellescape}",
        project: project,
        user: user,
        service_account: service_account
      )
      Base64.decode64(secret.dig("payload", "data"))
    end

    # The secret needs to at least contain a secret name, but project name, and secret version can also be specified.
    #
    # The string "default" can be used to refer to the default project configured for gcloud.
    #
    # The version can be either the string "latest", or a version number.
    #
    # The following formats are valid:
    #
    # - The following are all equivalent, and sets project: default, secret name: my-secret, version: latest
    #   - "my-secret"
    #   - "default/my-secret"
    #   - "default/my-secret/latest"
    #   - "my-secret/latest" in combination with --from=default
    # - "my-secret/123" (only in combination with --from=some-project) -> project: some-project, secret name: my-secret, version: 123
    # - "some-project/my-secret/123" -> project: some-project, secret name: my-secret, version: 123
    def secrets_with_metadata(secrets)
      {}.tap do |items|
        secrets.each do |secret|
          parts = secret.split("/")
          parts.unshift("default") if parts.length == 1
          project = parts.shift
          secret_name = parts.shift
          secret_version = parts.shift || "latest"

          items[secret] = [ project, secret_name, secret_version ]
        end
      end
    end

    def run_command(command, project: "default", user: "default", service_account: nil)
      full_command = [ "gcloud", command ]
      full_command << "--project=#{project.shellescape}" unless project == "default"
      full_command << "--account=#{user.shellescape}" unless user == "default"
      full_command << "--impersonate-service-account=#{service_account.shellescape}" if service_account
      full_command << "--format=json"
      full_command = full_command.join(" ")

      result = `#{full_command}`.strip
      JSON.parse(result)
    end

    def check_dependencies!
      raise RuntimeError, "gcloud CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `gcloud --version 2> /dev/null`
      $?.success?
    end

    def logged_in?
      JSON.parse(`gcloud auth list --format=json`).any?
    end

    def parse_account(account)
      account.split("|", 2)
    end

    def is_user?(candidate)
      candidate.include?("@")
    end
end
