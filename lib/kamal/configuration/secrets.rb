class Kamal::Configuration::Secrets
  attr_reader :secret_file, :destination

  def initialize(destination: nil)
    @destination = destination
    @secret_file = (destination ? [ ".kamal/secrets.#{destination}", ".kamal/secrets" ] : [ ".kamal/secrets" ])
      .find { |file| File.exist?(file) }
  end

  def [](key)
    @secrets ||= load
    @secrets.fetch(key)
  rescue KeyError
    if secret_file
      raise Kamal::ConfigurationError, "Secret '#{key}' not found in #{secret_file}"
    else
      raise Kamal::ConfigurationError, "Secret '#{key}' not found, no secret file provided"
    end
  end

  private
    def load
      original_env = ENV.to_hash
      ENV["KAMAL_DESTINATION"] = destination if destination
      secret_file ? Dotenv.parse(*secret_file) : {}
    ensure
      ENV.replace(original_env)
    end
end
