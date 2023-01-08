require "sshkit"
require "sshkit/dsl"

include SSHKit::DSL

MRSK_CONFIG = Mrsk::Configuration.load_file(Rails.root.join("config/deploy.yml"))

SSHKit::Backend::Netssh.configure { |ssh| ssh.ssh_options = MRSK_CONFIG.ssh_options }

# No need to use /usr/bin/env, just clogs up the logs
SSHKit.config.command_map[:docker] = "docker"
