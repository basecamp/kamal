require "sshkit"
require "sshkit/dsl"

module AppHelper
  def stale_versions(role:)
    capture_with_info(*MRSK.app(role: role).list_versions, raise_on_non_zero_exit: false)
      .split("\n")
      .drop(1)
  end
end

class SSHKit::Backend::Abstract
  include AppHelper

  def capture_with_info(*args, **kwargs)
    capture(*args, **kwargs, verbosity: Logger::INFO)
  end

  def puts_by_host(host, output, type: "App")
    puts "#{type} Host: #{host}\n#{output}\n\n"
  end
end
