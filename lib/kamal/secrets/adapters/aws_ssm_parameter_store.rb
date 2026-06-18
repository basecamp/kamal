class Kamal::Secrets::Adapters::AwsSsmParameterStore < Kamal::Secrets::Adapters::Base
  MAX_PARAMETERS_PER_REQUEST = 10

  def requires_account?
    false
  end

  private
    def login(_account)
      nil
    end

    def fetch_secrets(secrets, from:, account: nil, session:)
      {}.tap do |results|
        prefixed_secrets(secrets, from: from).each_slice(MAX_PARAMETERS_PER_REQUEST) do |batch|
          get_from_parameter_store(batch, account: account).each do |secret|
            results[secret["Name"]] = secret["Value"]
          end
        end
      end
    end

    def get_from_parameter_store(secrets, account: nil)
      args = [ "aws", "ssm", "get-parameters", "--names" ] + secrets.map(&:shellescape)
      # We have to pass --with-decryption. Otherwise, we would get the raw encrypted value for secrets with type SecureString (AWS KMS encrypted secrets).
      args += [ "--with-decryption" ]
      args += [ "--profile", account.shellescape ] if account
      args += [ "--output", "json" ]
      cmd = args.join(" ")

      `#{cmd}`.tap do |response|
        raise RuntimeError, "Could not read from AWS SSM Parameter Store" unless $?.success?

        response = JSON.parse(response)

        return response["Parameters"] unless response["InvalidParameters"].present?

        raise RuntimeError, response["InvalidParameters"].map { |name| "#{name}: SSM Parameter Store can't find the specified secret." }.join(" ")
      end
    end

    def check_dependencies!
      raise RuntimeError, "AWS CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `aws --version 2> /dev/null`
      $?.success?
    end
end
