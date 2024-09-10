class Kamal::Cli::Secrets < Kamal::Cli::Base
  desc "fetch [SECRETS...]", "Fetch secrets from a vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :account, type: :string, required: true, desc: "The account identifier or username"
  option :from, type: :string, required: false, desc: "A vault or folder to fetch the secrets from"
  option :inline, type: :boolean, required: false, hidden: true
  def fetch(*secrets)
    handle_output(inline: options[:inline]) do
      results = adapter(options[:adapter]).fetch(secrets, **options.slice(:account, :from).symbolize_keys)
      JSON.dump(results).shellescape
    end
  end

  desc "extract", "Extract a single secret from the results of a fetch call"
  option :inline, type: :boolean, required: false, hidden: true
  def extract(name, secrets)
    handle_output(inline: options[:inline]) do
      parsed_secrets = JSON.parse(secrets)

      value = parsed_secrets[name] || parsed_secrets.find { |k, v| k.end_with?("/#{name}") }&.last

      raise "Could not find secret #{name}" if value.nil?

      value
    end
  end

  private
    def adapter(adapter)
      Kamal::Secrets::Adapters.lookup(adapter)
    end

    def handle_output(inline: nil)
      yield.tap do |output|
        puts output unless inline
      end
    rescue => e
      handle_error(e)
    end

    def handle_error(e)
      $stderr.puts "  \e[31mERROR (#{e.class}): #{e.message}\e[0m"
      $stderr.puts e.backtrace if ENV["VERBOSE"]

      exit 1
    end
end
