require "open3"

##
# Enpass is different from most password managers, in a way that it's offline. A path to a vault is treated as account.
#
# Pass it like so: `kamal secrets fetch --adapter enpass --account /Users/YOUR_USERNAME/Library/Containers/in.sinew.Enpass-Desktop/Data/Documents/Vaults/primary --from MY_PROD_SERVER`
class Kamal::Secrets::Adapters::Enpass < Kamal::Secrets::Adapters::Base
  private
    def login(account)
      # There is no concept of session in enpass-cli
      true
    end

    def fetch_secrets(secrets, account:, session:)
      secrets_titles = fetch_secret_titles(secrets)

      # Enpass outputs result as stderr, I did not find a way to stub backticks and output to stderr. Open3 did the job.
      result = `enpass-cli -json -vault #{account.shellescape} show #{secrets.map(&:shellescape).join(" ")}`.strip

      parse_result_and_take_secrets(result, secrets)
    end

    def check_dependencies!
      raise RuntimeError, "Enpass CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `enpass-cli version 2> /dev/null`
      $?.success?
    end

    def fetch_secret_titles(secrets)
      secrets.reduce(Set.new) do |secret_titles, secret|
        # Sometimes secrets contain a '/', when the intent is to fetch a single password for an item. Example: FooBar/DB_PASSWORD
        # Another case is, when the intent is to fetch all passwords for an item. Example: FooBar (and FooBar may have multiple different passwords)
        key, separator, value = secret.rpartition("/")
        if key.empty?
          secret_titles << value
        else
          secret_titles << key
        end
      end.to_a
    end

    def parse_result_and_take_secrets(unparsed_result, secrets)
      result = JSON.parse(unparsed_result)

      result.reduce({}) do |secrets_with_passwords, item|
        title = item["title"]
        label = item["label"]
        password = item["password"]

        if title && password.present?
          key = [ title, label ].compact.reject(&:empty?).join("/")

          if secrets.include?(title) || secrets.include?(key)
            raise RuntimeError, "#{key} is present more than once" if secrets_with_passwords[key]
            secrets_with_passwords[key] = password
          end
        end

        secrets_with_passwords
      end
    end
end
