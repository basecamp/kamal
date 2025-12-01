require "dotenv"

class Kamal::Secrets
  Kamal::Secrets::Dotenv::InlineCommandSubstitution.install!

  def initialize(destination: nil, secrets_path:)
    @destination = destination
    @secrets_path = secrets_path
    @mutex = Mutex.new
  end

  def [](key)
    synchronized_fetch(key)
  rescue KeyError
    if secrets_files.present?
      raise Kamal::ConfigurationError, "Secret '#{key}' not found in #{secrets_files.join(", ")}"
    else
      raise Kamal::ConfigurationError, "Secret '#{key}' not found, no secret files (#{secrets_filenames.join(", ")}) provided"
    end
  end

  def to_h
    secrets
  end

  def secrets_files
    @secrets_files ||= secrets_filenames.select { |f| File.exist?(f) }
  end

  def key?(key)
    synchronized_fetch(key).present?
  rescue KeyError
    false
  end

  private
    def secrets
      @secrets ||= secrets_files.inject({}) do |secrets, secrets_file|
        secrets.merge!(::Dotenv.parse(secrets_file, overwrite: true))
      end
    end

    def secrets_filenames
      [ "#{@secrets_path}-common", "#{@secrets_path}#{(".#{@destination}" if @destination)}" ]
    end

    def synchronized_fetch(key)
      # Fetching secrets may ask the user for input, so ensure only one thread does that
      @mutex.synchronize do
        secrets.fetch(key)
      end
    end
end
