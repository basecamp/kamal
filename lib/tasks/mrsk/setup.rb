require "sshkit"
require "sshkit/dsl"

include SSHKit::DSL

if (config_file = Rails.root.join("config/deploy.yml")).exist?
  MRSK_CONFIG = Mrsk::Configuration.load_file(config_file)

  SSHKit::Backend::Netssh.configure { |ssh| ssh.ssh_options = MRSK_CONFIG.ssh_options }

  # No need to use /usr/bin/env, just clogs up the logs
  SSHKit.config.command_map[:docker] = "docker"
else
  # MRSK is missing config/deploy.yml – run 'rake mrsk:init'
  MRSK_CONFIG = Mrsk::Configuration.new({}, validate: false)
end
