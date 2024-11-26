class Kamal::Secrets::Adapters::Base
  delegate :optionize, to: Kamal::Utils

  def fetch(secrets, account: nil, from: nil)
    raise RuntimeError, "Missing required option '--account'" if requires_account? && account.blank?

    check_dependencies!

    session = login(account)
    full_secrets = secrets.map { |secret| [ from, secret ].compact.join("/") }
    fetch_secrets(full_secrets, account: account, session: session)
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
end
