require "dotenv"

class Kamal::Secrets
  attr_reader :secrets_files

  Kamal::Secrets::Dotenv::InlineCommandSubstitution.install!

  def initialize(destination: nil)
    @secrets_files = \
      [ ".kamal/secrets-common", ".kamal/secrets#{(".#{destination}" if destination)}" ].select { |f| File.exist?(f) }
    @mutex = Mutex.new
  end

  def [](key)
    # Fetching secrets may ask the user for input, so ensure only one thread does that
    @mutex.synchronize do
      secrets.fetch(key)
    end
  rescue KeyError
    if secrets_files
      raise Kamal::ConfigurationError, "Secret '#{key}' not found in #{secrets_files.join(", ")}"
    else
      raise Kamal::ConfigurationError, "Secret '#{key}' not found, no secret files provided"
    end
  end

  def to_h
    secrets
  end

  private
    def secrets
      @secrets ||= secrets_files.inject({}) do |secrets, secrets_file|
        secrets.merge!(::Dotenv.parse(secrets_file))
      end
    end
end
