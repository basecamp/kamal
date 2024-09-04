class Kamal::Secrets::Adapters::Test < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      true
    end

    def fetch_from_vault(secrets, account:, session:)
      secrets.to_h { |secret| [ secret, secret.reverse ] }
    end
end
