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
      _stdout, stderr, status = Open3.capture3("enpass-cli -vault #{account.shellescape} show #{secrets_titles.map(&:shellescape).join(" ")}")
      raise RuntimeError, "Could not read #{secrets} from Enpass" unless status.success?

      parse_result_and_take_secrets(stderr, secrets)
    end

    def check_dependencies!
      raise RuntimeError, "Enpass CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `enpass-cli version 2> /dev/null`
      $?.success?
    end

    def fetch_secret_titles(secrets)
      secrets.reduce(Set.new) do |acc, secret|
        # Sometimes secrets contain a '/', sometimes not
        key, separator, value = secret.rpartition("/")
        if key.empty?
          acc << value
        else
          acc << key
        end
      end.to_a
    end

    def parse_result_and_take_secrets(unparsed_result, secrets)
      unparsed_result.split("\n").reduce({}) do |acc, line|
        title = line[/title:\s*(\w+)/, 1]
        label = line[/label:\s*(.*?)\s{2}/, 1]
        password = line[/password:\s*([^"]+)/, 1]

        if title && !password.to_s.empty?
          key = label.nil? || label.empty? ? title : "#{title}/#{label}"
          if secrets.include?(title) || secrets.include?(key)
            raise RuntimeError, "#{key} is present more than once" if acc[key]
            acc[key] = password
          end
        end

        acc
      end
    end
end
