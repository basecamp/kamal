require "dotenv"

class Kamal::Secrets
  attr_reader :secrets_file

  Kamal::Secrets::Dotenv::InlineCommandSubstitution.install!

  def initialize(destination: nil)
    @secrets_file = [ *(".kamal/secrets.#{destination}" if destination), ".kamal/secrets" ].find { |f| File.exist?(f) }
  end

  def [](key)
    secrets.fetch(key)
  rescue KeyError
    if secrets_file
      raise Kamal::ConfigurationError, "Secret '#{key}' not found in #{secrets_file}"
    else
      raise Kamal::ConfigurationError, "Secret '#{key}' not found, no secret files provided"
    end
  end

  def to_h
    secrets
  end

  private
    def secrets
      @secrets ||= parse_secrets
    end

    def parse_secrets
      if secrets_file
        ::Dotenv.parse(secrets_file)
      else
        {}
      end
    end
end
