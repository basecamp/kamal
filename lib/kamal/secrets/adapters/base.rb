class Kamal::Secrets::Adapters::Base
  delegate :optionize, to: Kamal::Utils

  def fetch(secrets, account:, from: nil)
    session = login(account)
    full_secrets = secrets.map { |secret| [ from, secret ].compact.join("/") }
    fetch_secrets(full_secrets, account: account, session: session)
  end

  private
    def login(...)
      raise NotImplementedError
    end

    def fetch_secrets(...)
      raise NotImplementedError
    end
end
