class Kamal::Secrets::Adapters::Base
  delegate :optionize, to: Kamal::Utils

  def fetch(secrets, account:, from: nil)
    session = login(account)
    full_secrets = secrets.map { |secret| [ from, secret ].compact.join("/") }
    fetch_from_vault(full_secrets, account: account, session: session)
  rescue => e
    $stderr.puts "  \e[31mERROR (#{e.class}): #{e.message}\e[0m"
    $stderr.puts e.backtrace if ENV["VERBOSE"]

    Process.kill("INT", Process.ppid) if ENV["KAMAL_SECRETS_INT_PARENT"]
    exit 1
  end

  private
    def login(...)
      raise NotImplementedError
    end

    def fetch_from_vault(...)
      raise NotImplementedError
    end
end
