class Kamal::Secrets::Adapters::Test < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      true
    end

    def fetch_secrets(secrets, account:, session:)
      secrets.to_h { |secret| [ secret, secret.reverse ] }
    end

    def check_dependencies!
      # no op
    end
end
