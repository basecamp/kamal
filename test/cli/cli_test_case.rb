require "test_helper"

class CliTestCase < ActiveSupport::TestCase
  setup do
    ENV["VERSION"]             = "999"
    ENV["RAILS_MASTER_KEY"]    = "123"
    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
    Object.send(:remove_const, :KAMAL)
    Object.const_set(:KAMAL, Kamal::Commander.new)
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("MYSQL_ROOT_PASSWORD")
    ENV.delete("VERSION")
  end

  private
    def fail_hook(hook)
      @executions = []
      Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| @executions << args; args != [ ".kamal/hooks/#{hook}" ] }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| args.first == ".kamal/hooks/#{hook}" }
        .raises(SSHKit::Command::Failed.new("failed"))
    end

    def stub_setup
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| args == [ :mkdir, "-p", ".kamal" ] }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2, arg3| arg1 == :mkdir && arg2 == "-p" && arg3 == ".kamal/locks" }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :mkdir && arg2 == ".kamal/locks/app" }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :rm && arg2 == ".kamal/locks/app/details" }
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
        .with { |*args| args[0..2] == [ :docker, :buildx, :inspect ] }
        .returns("")
    end

    def assert_hook_ran(hook, output, version:, service_version:, hosts:, command:, subcommand: nil, runtime: false)
      performer = `whoami`.strip
      service = service_version.split("@").first

      assert_match "Running the #{hook} hook...\n", output

      expected = %r{Running\s/usr/bin/env\s\.kamal/hooks/#{hook}\sas\s#{performer}@localhost\n\s
        DEBUG\s\[[0-9a-f]*\]\sCommand:\s\(\sexport\s
        KAMAL_RECORDED_AT=\"\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ\"\s
        KAMAL_PERFORMER=\"#{performer}\"\s
        KAMAL_VERSION=\"#{version}\"\s
        KAMAL_SERVICE_VERSION=\"#{service_version}\"\s
        KAMAL_SERVICE=\"#{service}\"\s
        KAMAL_HOSTS=\"#{hosts}\"\s
        KAMAL_COMMAND=\"#{command}\"\s
        #{"KAMAL_SUBCOMMAND=\\\"#{subcommand}\\\"\\s" if subcommand}
        #{"KAMAL_RUNTIME=\\\"\\d+\\\"\\s" if runtime}
        ;\s/usr/bin/env\s\.kamal/hooks/#{hook} }x

      assert_match expected, output
    end
end
