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

end
