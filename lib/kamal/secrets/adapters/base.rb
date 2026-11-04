class Kamal::Secrets::Adapters::Base
  delegate :optionize, to: Kamal::Utils

  def fetch(secrets, account: nil, from: nil)
    raise RuntimeError, "Missing required option '--account'" if requires_account? && account.blank?

    check_dependencies!

    session = login(account)
    fetch_secrets(secrets, from: from, account: account, session: session)
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

    # Runs the command directly, without a shell, and returns its output, setting $? like backticks.
    # Pass credentials through env so they never appear in a process's command line.
    def capture_command(*argv, env: {})
      IO.popen(env, argv, &:read)
    end
end
