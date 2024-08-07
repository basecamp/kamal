class Kamal::Secrets
  attr_reader :secrets_file

  def initialize(destination: nil)
    @secrets_file = [ *(".kamal/secrets.#{destination}" if destination), ".kamal/secrets" ].find { |f| File.exist?(f) }
  end

  def [](key)
    @secrets ||= secrets_file ? Dotenv.parse(*secrets_file) : {}
    @secrets.fetch(key)
  rescue KeyError
    if secrets_file
      raise Kamal::ConfigurationError, "Secret '#{key}' not found in #{secrets_file}"
    else
      raise Kamal::ConfigurationError, "Secret '#{key}' not found, no secret files provided"
    end
  end
end
