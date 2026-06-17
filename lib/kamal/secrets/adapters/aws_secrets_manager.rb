class Kamal::Secrets::Adapters::AwsSecretsManager < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private
    def login(_account)
      nil
    end

    def fetch_secrets(secrets, from:, account: nil, session:)
      {}.tap do |results|
        get_from_secrets_manager(prefixed_secrets(secrets, from: from), account: account).each do |secret|
          secret_name = secret["Name"]
          secret_string = JSON.parse(secret["SecretString"])

          if secret_string.is_a?(Hash)
            secret_string.each do |key, value|
              results["#{secret_name}/#{key}"] = stringify_secret_value(value)
            end
          else
            results["#{secret_name}"] = stringify_secret_value(secret_string)
          end
        rescue JSON::ParserError
          results["#{secret_name}"] = secret["SecretString"]
        end
      end
    end

    def get_from_secrets_manager(secrets, account: nil)
      args = [ "aws", "secretsmanager", "batch-get-secret-value", "--secret-id-list" ] + secrets.map(&:shellescape)
      args += [ "--profile", account.shellescape ] if account
      args += [ "--output", "json" ]
      cmd = args.join(" ")

      `#{cmd}`.tap do |secrets|
        raise RuntimeError, "Could not read #{secrets} from AWS Secrets Manager" unless $?.success?

        secrets = JSON.parse(secrets)

        return secrets["SecretValues"] unless secrets["Errors"].present?

        raise RuntimeError, secrets["Errors"].map { |error| "#{error['SecretId']}: #{error['Message']}" }.join(" ")
      end
    end

    def stringify_secret_value(value)
      value.is_a?(String) ? value : JSON.dump(value)
    end

    def check_dependencies!
      raise RuntimeError, "AWS CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `aws --version 2> /dev/null`
      $?.success?
    end
end
