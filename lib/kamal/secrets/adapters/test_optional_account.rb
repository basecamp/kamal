class Kamal::Secrets::Adapters::TestOptionalAccount < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

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
