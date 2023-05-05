require "sshkit"
require "sshkit/dsl"
require "json"

class SSHKit::Backend::Abstract
  def capture_with_info(*args, **kwargs)
    capture(*args, **kwargs, verbosity: Logger::INFO)
  end

  def puts_by_host(host, output, type: "App")
    puts "#{type} Host: #{host}\n#{output}\n\n"
  end

  def capture_with_pretty_json(*args, **kwargs)
    JSON.pretty_generate(JSON.parse(capture(*args, **kwargs)))
  end
end
