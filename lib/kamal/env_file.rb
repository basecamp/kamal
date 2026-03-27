# Encode an env hash as a string where secret values have been looked up and all values escaped for Docker.
class Kamal::EnvFile
  def initialize(env)
    @env = env
  end

  def to_s
    env_file = StringIO.new.tap do |contents|
      @env.each do |key, value|
        contents << docker_env_file_line(key, value)
      end
    end.string

    # Ensure the file has some contents to avoid the SSHKIT empty file warning
    env_file.presence || "\n"
  end

  def to_io
    StringIO.new(to_s)
  end

  alias to_str to_s

  private
    def docker_env_file_line(key, value)
      value = value.to_s

      # Docker env files don't support escape sequences, so newlines and null
      # bytes cannot be represented. Raise an error rather than silently corrupt.
      raise ArgumentError, "Env file values cannot contain newlines" if value.include?("\n")
      raise ArgumentError, "Env file values cannot contain null bytes" if value.include?("\0")

      "#{key}=#{value}\n"
    end
end
