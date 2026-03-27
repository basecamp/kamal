require "open3"
require "io/console"

class Kamal::Secrets::Adapters::Keepassxc < Kamal::Secrets::Adapters::Base
  # Usage Example:
  # kamal secrets fetch --adapter keepassxc --account ~/path/to/secrets.kdbx --from entry-title KAMAL_REGISTRY_PASSWORD RAILS_MASTER_KEY ANY_OTHER_ATTRIBUTE_SAVED_IN_ADVANCE_TAB_OF_AN_ENTRY

  private

  def check_dependencies!
    raise "KeePassXC CLI is not installed." unless cli_installed?
  end

  def login(account)
    ask_for_password(account)
  end

  def fetch_secrets(secrets, from:, account:, session:)
    secrets.each_with_object({}) do |secret, results|
      # If asking for "password", use standard field, otherwise use Attribute lookup
      attr_flag = (secret == "password") ? [] : ["-a", secret]
      results[secret] = run_command("show", account, from, *attr_flag, "-q", "--show-protected", session: session)
    end
  end

  def cli_installed?
    `keepassxc-cli --version 2> /dev/null`
    $?.success?
  end

  def ask_for_password(account)
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
