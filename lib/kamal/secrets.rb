class Kamal::Secrets
  attr_reader :secrets_file

  def initialize(destination: nil)
    @secrets_file = [ *(".kamal/secrets.#{destination}" if destination), ".kamal/secrets" ].find { |f| File.exist?(f) }
  end

  def [](key)
    @secrets ||= parse_secrets
    @secrets.fetch(key)
  rescue KeyError
    if secrets_file
      raise Kamal::ConfigurationError, "Secret '#{key}' not found in #{secrets_file}"
    else
      raise Kamal::ConfigurationError, "Secret '#{key}' not found, no secret files provided"
    end
  end

  private
    def parse_secrets
      if secrets_file
        interrupting_parent_on_error { Dotenv.parse(secrets_file) }
      else
        {}
      end
    end

    def interrupting_parent_on_error
      # Make any `kamal secrets` calls in dotenv interpolation interrupt this process if there are errors
      ENV["KAMAL_SECRETS_INT_PARENT"] = "1"
      yield
    ensure
      ENV.delete("KAMAL_SECRETS_INT_PARENT")
    end
end
