require "dotenv"

class Kamal::Secrets
  Kamal::Secrets::Dotenv::InlineCommandSubstitution.install!

  def initialize(destination: nil, secrets_path:)
    @destination = destination
    @secrets_path = secrets_path
    @mutex = Mutex.new
  end

  def [](key)
    # Fetching secrets may ask the user for input, so ensure only one thread does that
    value = @mutex.synchronize do
      secrets.fetch(key)
    end

    blank_key_warning(key) unless value.present?

    value
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

  private
    def blank_key_warning(key)
      warn "Warning: Kamal secret #{key} is blank."
      secrets_files.each do |secrets_file|
        next unless File.exist?(secrets_file)

        File.foreach(secrets_file).with_index do |line, line_num|
          next unless line.match?(/^\s*#{key}=/)

          warn "Tip: see #{secrets_file}:#{line_num + 1}: #{line.strip}"
          if line.match?(/^\s*#{key}=\$\w+/)
            warn "Tip: the environment variable #{key} is #{ENV[key].nil? ?
              "not set" : "blank"}. Did you forget to set it?"
          elsif (matches = line.match(/^\s*#{key}=\$\(([^)]+)\)/)).present?
            warn "Tip: the shell command \`#{matches[1]}\` returned an empty value."
          end
        end
      end
    end

    def secrets
      @secrets ||= secrets_files.inject({}) do |secrets, secrets_file|
        secrets.merge!(::Dotenv.parse(secrets_file, overwrite: true))
      end
    end

    def secrets_filenames
      [ "#{@secrets_path}-common", "#{@secrets_path}#{(".#{@destination}" if @destination)}" ]
    end

    # Suppress warnings if launched from bin/test
    alias_method :kernel_warn, :warn
    def warn(message)
      return if ENV["RAILS_ENV"] == "test"

      kernel_warn message
    end
end
