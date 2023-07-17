require "test_helper"

class CliTestCase < ActiveSupport::TestCase
  setup do
    ENV["VERSION"]             = "999"
    ENV["RAILS_MASTER_KEY"]    = "123"
    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
    Object.send(:remove_const, :MRSK)
    Object.const_set(:MRSK, Mrsk::Commander.new)
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("MYSQL_ROOT_PASSWORD")
    ENV.delete("VERSION")
  end

  private
    def fail_hook(hook)
      @executions = []
      Mrsk::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| @executions << args; args != [".mrsk/hooks/#{hook}"] }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| args.first == ".mrsk/hooks/#{hook}" }
        .raises(SSHKit::Command::Failed.new("failed"))
    end

    def stub_locking
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :mkdir && arg2 == "mrsk_lock-app" }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :rm && arg2 == "mrsk_lock-app/details" }
    end

    def assert_hook_ran(hook, output, version:, service_version:, hosts:, command:, subcommand: nil, runtime: nil)
      performer = `whoami`.strip

      assert_match "Running the #{hook} hook...\n", output

      expected = %r{Running\s/usr/bin/env\s\.mrsk/hooks/#{hook}\sas\s#{performer}@localhost\n\s
        DEBUG\s\[[0-9a-f]*\]\sCommand:\s\(\sexport\s
        MRSK_RECORDED_AT=\"\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ\"\s
        MRSK_PERFORMER=\"#{performer}\"\s
        MRSK_VERSION=\"#{version}\"\s
        MRSK_SERVICE_VERSION=\"#{service_version}\"\s
        MRSK_HOSTS=\"#{hosts}\"\s
        MRSK_COMMAND=\"#{command}\"\s
        #{"MRSK_SUBCOMMAND=\\\"#{subcommand}\\\"\\s" if subcommand}
        #{"MRSK_RUNTIME=\\\"#{runtime}\\\"\\s" if runtime}
        ;\s/usr/bin/env\s\.mrsk/hooks/#{hook} }x

      assert_match expected, output
    end
end
