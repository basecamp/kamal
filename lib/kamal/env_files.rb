# Encode an env hash as a string where secret values have been looked up and all values escaped for Docker.
class Kamal::EnvFiles
  def initialize(env)
    @env = env
  end

  def secret
    env_file do
      @env["secret"]&.to_h { |key| [ key, ENV.fetch(key) ] }
    end
  end

  def clear
    env_file do
      if (secrets = @env["secret"]).present?
        @env["clear"]
      else
        @env.fetch("clear", @env)
      end
    end
  end

  private
    def docker_env_file_line(key, value)
      "#{key.to_s}=#{escape_docker_env_file_value(value)}\n"
    end

    # Escape a value to make it safe to dump in a docker file.
    def escape_docker_env_file_value(value)
      # Doublequotes are treated literally in docker env files
      # so remove leading and trailing ones and unescape any others
      value.to_s.dump[1..-2].gsub(/\\"/, "\"")
    end

    def env_file(&block)
      StringIO.new.tap do |contents|
        block.call&.each do |key, value|
          contents << docker_env_file_line(key, value)
        end
        # Ensure the file has some contents to avoid the SSHKit empty file warning
        contents << "\n" if contents.length == 0
      end.string
    end
end
