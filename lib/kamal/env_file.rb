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

  alias to_str to_s

  private
    def docker_env_file_line(key, value)
      "#{key}=#{escape_docker_env_file_value(value)}\n"
    end

    # Escape a value to make it safe to dump in a docker file.
    def escape_docker_env_file_value(value)
      # Doublequotes are treated literally in docker env files
      # so remove leading and trailing ones and unescape any others
      value.to_s.dump[1..-2].gsub(/\\"/, "\"")
    end
end
