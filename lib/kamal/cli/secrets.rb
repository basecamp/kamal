class Kamal::Cli::Secrets < Kamal::Cli::Base
  desc "fetch [SECRETS...]", "Fetch secrets from a vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :account, type: :string, required: true, desc: "The account identifier or username"
  option :location, type: :string, required: false, desc: "A vault or folder to fetch the secrets from"
  def fetch(*secrets)
    ENV["KAMAL_SECRETS_KILL_PARENT"] = "1"

    results = adapter(options[:adapter]).fetch(secrets, **options.slice(:account, :location).symbolize_keys)
    puts JSON.dump(results).shellescape
  end

  desc "extract", "Extract a single secret from the results of a fetch call"
  def extract(name, secrets)
    puts JSON.parse(secrets).fetch(name)
  end

  private
    def adapter(adapter)
      Kamal::Secrets::Adapters.lookup(adapter)
    end
end
