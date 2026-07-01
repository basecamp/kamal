# Fetches secrets from a sops (https://github.com/getsops/sops) encrypted file.
#
# The `--from` option names the encrypted file to decrypt; the positional secrets are keys
# within it. sops resolves the decryption key itself (age/KMS/PGP/etc.) from its own config
# and environment, so no `--account` is required. The file is decrypted once per call.
#
# Nested structures are flattened into `parent/child` paths, and non-string values are
# coerced to strings. When no keys are given, every (flattened) key in the file is returned.
#
# Given secrets.enc.yaml:
#
#   database:
#     password: pw       # => database/password
#     host: db.example   # => database/host
#   api_key: xyz         # => api_key
#
# Examples:
#
#   # Fetch specific keys
#   kamal secrets fetch --adapter sops --from secrets.enc.yaml database/password api_key
#
#   # Fetch a whole subtree by its parent key (returns database/password and database/host)
#   kamal secrets fetch --adapter sops --from secrets.enc.yaml database
#
#   # Fetch every key in the file
#   kamal secrets fetch --adapter sops --from secrets.enc.yaml
class Kamal::Secrets::Adapters::Sops < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private
    def login(_account)
      nil
    end

    def fetch_secrets(secrets, from:, account: nil, session:)
      raise RuntimeError, "Missing required option '--from'" if from.blank?

      all_secrets = flatten_secrets(decrypt(from))

      if secrets.blank?
        all_secrets
      else
        select_secrets(all_secrets, secrets, from: from)
      end
    end

    def decrypt(from)
      contents = `sops --decrypt --output-type json -- #{from.shellescape}`
      raise RuntimeError, "Could not decrypt #{from} with sops" unless $?.success?

      parsed = JSON.parse(contents)
      raise RuntimeError, "Expected #{from} to decrypt to a JSON object" unless parsed.is_a?(Hash)

      parsed
    end

    def select_secrets(all_secrets, secrets, from:)
      {}.tap do |results|
        secrets.each do |secret|
          matched = all_secrets.select { |path, _| path == secret || path.start_with?("#{secret}/") }
          raise RuntimeError, "Could not find secret #{secret} in #{from}" if matched.empty?

          results.merge!(matched)
        end
      end
    end

    def flatten_secrets(hash, prefix = nil)
      {}.tap do |results|
        hash.each do |key, value|
          path = [ prefix, key ].compact.join("/")

          if value.is_a?(Hash)
            results.merge!(flatten_secrets(value, path))
          else
            results[path] = stringify_secret_value(value)
          end
        end
      end
    end

    def stringify_secret_value(value)
      value.is_a?(String) ? value : JSON.dump(value)
    end

    def check_dependencies!
      raise RuntimeError, "sops is not installed" unless cli_installed?
    end

    def cli_installed?
      `sops --version 2> /dev/null`
      $?.success?
    end
end
