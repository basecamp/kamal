require "sshkit"
require "sshkit/dsl"

include SSHKit::DSL

MRSK_CONFIG = Mrsk::Configuration.load_file(Rails.root.join("config/deploy.yml"))

SSHKit::Backend::Netssh.configure do |ssh|
  ssh.ssh_options = { user: MRSK_CONFIG.ssh_user, auth_methods: [ "publickey" ] }
end
