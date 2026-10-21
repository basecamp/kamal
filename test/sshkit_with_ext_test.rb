require_relative "test_helper"

class SSHKitDslRolesTest < ActiveSupport::TestCase
  Role = Struct.new(:hosts)

  class Runner
    include SSHKit::DSL

    def on(hosts)
      Array(hosts).each { |host| yield SSHKit::Host.new(host) }
    end
  end

  test "sequential roles match hosts configured with an SSH user" do
    host = "appuser@192.168.12.100"
    role = Role.new([ host ])
    selected = []

    Runner.new.on_roles([ role ], hosts: [ host ], parallel: false) do |current_host, current_role|
      selected << [ current_host.hostname, current_role ]
    end

    assert_equal [ [ "192.168.12.100", role ] ], selected
  end
end
