require "sshkit"
require "sshkit/dsl"

class SSHKit::Backend::Abstract
  def capture_with_info(*args, **kwargs)
    capture(*args, **kwargs, verbosity: Logger::INFO)
  end

  def puts_by_host(host, output, type: "App")
    puts "#{type} Host: #{host}\n#{output}\n\n"
  end
end
