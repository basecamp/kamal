class Kamal::Configuration::Secrets
  attr_reader :secret_files

  def initialize(destination: nil)
    @secret_files = \
      (destination ? [ ".kamal/secrets.#{destination}", ".kamal/secrets" ] : [ ".kamal/secrets" ])
  end

  def [](key)
    @secrets ||= load
    @secrets.fetch(key)
  rescue KeyError
    if secret_files.any?
      raise Kamal::ConfigurationError, "Secret '#{key}' not found in #{secret_files.join(', ')}"
    else
      raise Kamal::ConfigurationError, "Secret '#{key}' not found, no secret files provided"
    end
  end

  private
    def load
      secret_files.any? ? Dotenv.parse(*secret_files) : {}
    end
end
