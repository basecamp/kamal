class Kamal::Cli::Secrets < Kamal::Cli::Base
  desc "fetch [SECRETS...]", "Fetch secrets from a vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :account, type: :string, required: true, desc: "The account identifier or username"
  option :from, type: :string, required: false, desc: "A vault or folder to fetch the secrets from"
  def fetch(*secrets)
    results = adapter(options[:adapter]).fetch(secrets, **options.slice(:account, :from).symbolize_keys)
    puts JSON.dump(results).shellescape
  rescue => e
    handle_error(e)
  end

  desc "extract", "Extract a single secret from the results of a fetch call"
  def extract(name, secrets)
    parsed_secrets = JSON.parse(secrets)

    if (value = parsed_secrets[name]).nil?
      value = parsed_secrets.find { |k, v| k.end_with?("/#{name}") }&.last
    end

    raise "Could not find secret #{name}" if value.nil?

    puts JSON.parse(secrets).fetch(name)
  rescue => e
    handle_error(e)
  end

  private
    def adapter(adapter)
      Kamal::Secrets::Adapters.lookup(adapter)
    end

    def handle_error(e)
      $stderr.puts "  \e[31mERROR (#{e.class}): #{e.message}\e[0m"
      $stderr.puts e.backtrace if ENV["VERBOSE"]

      Process.kill("INT", Process.ppid) if ENV["KAMAL_SECRETS_INT_PARENT"]
      exit 1
    end
end
