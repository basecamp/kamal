require "sshkit"
require "sshkit/dsl"

class SSHKit::Backend::Abstract
  def puts_by_host(host, output)
    puts "App Host: #{host}\n#{output}\n\n"
  end
end
