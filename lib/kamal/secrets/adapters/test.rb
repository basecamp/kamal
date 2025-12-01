class Kamal::Secrets::Adapters::Test < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      true
    end

    def fetch_secrets(secrets, from:, account:, session:)
      prefixed_secrets(secrets, from: from).to_h do |secret|
        [ secret, secret.gsub("LPAREN", "(").gsub("RPAREN", ")").reverse ]
      end
    end

    def check_dependencies!
      # no op
    end
end
