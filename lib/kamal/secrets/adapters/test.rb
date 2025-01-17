class Kamal::Secrets::Adapters::Test < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      true
    end

    def fetch_secrets(secrets, from:, account:, session:)
      prefixed_secrets(secrets, from: from).to_h { |secret| [ secret, secret.reverse ] }
    end

    def check_dependencies!
      # no op
    end
end
