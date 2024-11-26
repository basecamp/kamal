class Kamal::Cli::Secrets < Kamal::Cli::Base
  desc "fetch [SECRETS...]", "Fetch secrets from a vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :account, type: :string, required: false, desc: "The account identifier or username"
  option :from, type: :string, required: false, desc: "A vault or folder to fetch the secrets from"
  option :inline, type: :boolean, required: false, hidden: true
  def fetch(*secrets)
    adapter = initialize_adapter(options[:adapter])

    if adapter.requires_account? && options[:account].blank?
      return puts "No value provided for required options '--account'"
    end

    results = adapter.fetch(secrets, **options.slice(:account, :from).symbolize_keys)

    return_or_puts JSON.dump(results).shellescape, inline: options[:inline]
  end

  desc "extract", "Extract a single secret from the results of a fetch call"
  option :inline, type: :boolean, required: false, hidden: true
  def extract(name, secrets)
    parsed_secrets = JSON.parse(secrets)
    value = parsed_secrets[name] || parsed_secrets.find { |k, v| k.end_with?("/#{name}") }&.last

    raise "Could not find secret #{name}" if value.nil?

    return_or_puts value, inline: options[:inline]
  end

  desc "print", "Print the secrets (for debugging)"
  def print
    KAMAL.config.secrets.to_h.each do |key, value|
      puts "#{key}=#{value}"
    end
  end

  private
    def initialize_adapter(adapter)
      Kamal::Secrets::Adapters.lookup(adapter)
    end

    def return_or_puts(value, inline: nil)
      if inline
        value
      else
        puts value
      end
    end
end
