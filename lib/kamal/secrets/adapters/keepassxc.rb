##
# KeepassXC is an offline password manager that stores secrets in a local `.kdbx` database.
#
# Usage
#
# Fetch one password from an entry path:
# `kamal secrets fetch --adapter keepassxc --from /path/to/vault.kdbx app/KAMAL_REGISTRY_PASSWORD`
#
# You can provide the database password through `KEEPASSXC_PASSWORD` for non-interactive runs.
class Kamal::Secrets::Adapters::Keepassxc < Kamal::Secrets::Adapters::Base
  PASSWORD_ATTRIBUTE = "Password"

  def requires_account?
    false
  end

  private
    def login(*)
      nil
    end

    def fetch_secrets(secrets, from:, **)
      raise RuntimeError, "Missing database path from '--from=/path/to/database.kdbx' option" if from.blank?

      prefixed_secrets(secrets, from: nil).to_h do |secret|
        [ secret, fetch_secret(from, secret) ]
      end
    end

    def fetch_secret(database_path, entry_path)
      output = keepassxc_show(database_path, entry_path)
      lines = output.to_s.lines.map(&:strip).reject(&:blank?)
      password_line = lines.find { |line| line.match?(/\A#{PASSWORD_ATTRIBUTE}\s*:/i) }
      value = password_line ? password_line.sub(/\A#{PASSWORD_ATTRIBUTE}\s*:\s*/i, "") : lines.last.to_s
      value.strip
    end

    def keepassxc_show(database_path, entry_path)
      command = [
        "keepassxc-cli", "show", "--show-protected", "--attributes", PASSWORD_ATTRIBUTE,
        *(password_stdin_flag), database_path.shellescape, entry_path.shellescape
      ].join(" ")

      `#{password_prefix}#{command}`.tap do
        raise RuntimeError, "Could not read #{entry_path} from KeepassXC" unless $?.success?
      end
    end

    def password_prefix
      if ENV["KEEPASSXC_PASSWORD"].present?
        "printf %s\\\\n #{ENV["KEEPASSXC_PASSWORD"].shellescape} | "
      else
        ""
      end
    end

    def password_stdin_flag
      ENV["KEEPASSXC_PASSWORD"].present? ? [ "--pw-stdin" ] : []
    end

    def check_dependencies!
      raise RuntimeError, "KeepassXC CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `keepassxc-cli --version 2> /dev/null`
      $?.success?
    end
end
