require "dotenv"

class Kamal::Secrets
  Kamal::Secrets::Dotenv::InlineCommandSubstitution.install!

  # Bash parameter-expansion operators (e.g. ${VAR:-default}, ${VAR:?error}) that
  # the dotenv parser does not support. dotenv substitutes the variable name and
  # leaves the operator and default portion in the value verbatim, so we warn the
  # user rather than letting it happen silently. Plain ${VAR} and $(command) are
  # fine, and a backslash-escaped \${...} is treated as a literal by dotenv. The
  # /n flag keeps matching safe on files that contain non-UTF-8 bytes.
  UNSUPPORTED_EXPANSION = /(?<!\\)\$\{[A-Za-z_][A-Za-z0-9_]*:?[-+?=]/n

  def initialize(destination: nil, secrets_path: ".kamal/secrets")
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
        warn_on_unsupported_expansion(secrets_file)
        secrets.merge!(::Dotenv.parse(secrets_file, overwrite: true))
      end
    end

    def warn_on_unsupported_expansion(secrets_file)
      offending = File.binread(secrets_file).each_line.any? do |line|
        next false if line.match?(/\A\s*#/n)
        line.match?(UNSUPPORTED_EXPANSION)
      end
      return unless offending

      warn "Kamal secrets: #{secrets_file} uses ${VAR:-default}-style bash parameter expansion, which the secrets parser does not support. Only the variable name is substituted; the rest of the expression (e.g. ':-default}') is left in the value verbatim. Use a plain ${VAR} reference or compute the value with $(command) instead."
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
