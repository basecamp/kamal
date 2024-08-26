class Kamal::Cli::Secrets < Kamal::Cli::Base
  desc "fetch [ITEM] [FIELDS...]", "Fetch secrets from a vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :account, type: :string, aliases: "-a", required: true, desc: "The account identifier or username"
  def fetch(item, *fields)
    ENV["KAMAL_SECRETS_KILL_PARENT"] = "1"
    puts JSON.dump(adapter(options[:adapter]).fetch(item, fields, account: options[:account])).shellescape
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
