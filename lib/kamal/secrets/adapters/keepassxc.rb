require "open3"

class Kamal::Secrets::Adapters::Keepassxc < Kamal::Secrets::Adapters::Base
  # Usage Example:
  # kamal secrets fetch --adapter keepassxc --account ~/path/to/secrets.kdbx --from entry-title KAMAL_REGISTRY_PASSWORD RAILS_MASTER_KEY ANY_OTHER_ATTRIBUTE_SAVED_IN_ADVANCE_TAB_OF_AN_ENTRY

  private

  # 1. Login / Authentication
  def login(account)
    # In CI, we don't authenticate. Return a dummy session.
    return "ci-session" if ci_mode?

    if ENV["KEEPASS_PWD"] && !ENV["KEEPASS_PWD"].empty?
      ENV["KEEPASS_PWD"]
    else
      ask_for_password(account)
    end
  end

  # 2. Dispatcher
  def fetch_secrets(secrets, from:, account:, session:)
    if ci_mode?
      # CI Mode: Passthrough (Strict check)
      secrets.each_with_object({}) do |secret, results|
        value = ENV[secret]
        raise "Missing ENV secret '#{secret}' in CI mode." if value.nil? || value.empty?
        results[secret] = value
      end
    else
      # Local Mode: Fetch secrets.
      if secrets.empty?
        raise ArgumentError, "No secrets specified. Please list the attribute names you want to fetch."
      end
      fetch_specified_secrets(secrets, from: from, account: account, session: session)
    end
  end

  # 3. Fetch secrets
  def fetch_specified_secrets(secrets, from:, account:, session:)
    secrets.each_with_object({}) do |secret, results|
      # If asking for "password", use standard field, otherwise use Attribute lookup
      attr_flag = (secret == "password") ? [] : ["-a", secret]

      results[secret] = run_command("show", account, from, *attr_flag, "-q", "--show-protected", session: session)
    end
  end

  # 4. Check Dependencies
  def check_dependencies!
    # BYPASS: Don't check for CLI in CI
    return if ci_mode?
    raise "KeePassXC CLI is not installed" unless cli_installed?
  end

  def cli_installed?
    `keepassxc-cli --version 2> /dev/null`
    $?.success?
  end

  # --- Helpers ---

  def ci_mode?
    ENV["CI"] == "true" || ENV["GITHUB_ACTIONS"] == "true"
  end

  def ask_for_password(account)
    require "io/console"
    File.open("/dev/tty", "r+") do |tty|
      tty.getpass("Enter KeePassXC Master Password for #{File.basename(account)}: ")
    end
  end

  def run_command(*args, session:)
    cmd = ["keepassxc-cli", *args]
    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: session)
    raise "KeePassXC Error: #{stderr.strip}" unless status.success?
    stdout.strip
  end
end
