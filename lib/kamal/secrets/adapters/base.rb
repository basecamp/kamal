class Kamal::Secrets::Adapters::Base
  delegate :optionize, to: Kamal::Utils

  def fetch(secrets, account: nil, from: nil, server_url: nil)
    raise RuntimeError, "Missing required option '--account'" if requires_account? && account.blank?

    check_dependencies!

    session = login(account, server_url: server_url)
    fetch_secrets(secrets, from: from, account: account, session: session, server_url: server_url)
  end

  def requires_account?
    true
  end

  private
    def login(...)
      raise NotImplementedError
    end

    def fetch_secrets(...)
      raise NotImplementedError
    end

    def check_dependencies!
      raise NotImplementedError
    end

    def prefixed_secrets(secrets, from:)
      secrets.map { |secret| [ from, secret ].compact.join("/") }
    end
end
