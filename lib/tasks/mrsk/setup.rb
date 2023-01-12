require "sshkit"
require "sshkit/dsl"

include SSHKit::DSL

MRSK = Mrsk::Commander.new config_file: Rails.root.join("config/deploy.yml"), verbose: ENV["VERBOSE"]
