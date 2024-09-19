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
        .with { |*args| args == [ :mkdir, "-p", ".kamal/apps/app" ] }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2, arg3| arg1 == :mkdir && arg2 == "-p" && arg3 == ".kamal/lock-app" }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :mkdir && arg2 == ".kamal/lock-app" }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :rm && arg2 == ".kamal/lock-app/details" }
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with(:docker, :buildx, :inspect, "kamal-local-docker-container")
    end

    def assert_hook_ran(hook, output, version:, service_version:, hosts:, command:, subcommand: nil, runtime: false, secrets: false)
      assert_match %r{usr/bin/env\s\.kamal/hooks/#{hook}}, output
    end

    def with_argv(*argv)
      old_argv = ARGV
      ARGV.replace(*argv)
      yield
    ensure
      ARGV.replace(old_argv)
    end
end
