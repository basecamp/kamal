class Kamal::Cli::Secrets < Kamal::Cli::Base
  desc "login", "Login to a secrets vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :adapter_options, type: :hash, aliases: "-O", required: false, desc: "Options to pass to the vault adapter"
  def login
    puts adapter(options).login(**adapter_options(options))
  end

  desc "fetch", "Fetch a secret from a vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :adapter_options, type: :hash, aliases: "-O", required: false, desc: "Options to pass to the vault adapter"
  def fetch(name)
    puts adapter(options).fetch(name, **adapter_options(options))
  end

  desc "fetch_all", "Fetch multiple secrets from a vault"
  option :adapter, type: :string, aliases: "-a", required: true, desc: "Which vault adapter to use"
  option :adapter_options, type: :hash, aliases: "-O", required: false, desc: "Options to pass to the vault adapter"
  def fetch_all(*names)
    puts JSON.dump(adapter(options).fetch_all(*names, **adapter_options(options))).shellescape
  end

  desc "extract", "Extract a single secret from the results of a fetch_all call"
  def extract(name, secrets)
    puts JSON.parse(secrets).fetch(name)
  end

  private
    def adapter(options)
      Kamal::Secrets::Adapters.lookup(options[:adapter])
    end

    def adapter_options(options)
      options.fetch(:adapter_options, {}).transform_keys(&:to_sym)
    end
end
