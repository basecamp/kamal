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

    def assert_hook_ran(hook, output, count: 1)
      regexp = ([ "/usr/bin/env .kamal/hooks/#{hook}" ] * count).join(".*")
      assert_match /#{regexp}/m, output
    end

    def with_argv(*argv)
      old_argv = ARGV
      ARGV.replace(*argv)
      yield
    ensure
      ARGV.replace(old_argv)
    end

    def with_build_directory
      build_directory = File.join Dir.tmpdir, "kamal-clones", "app-#{pwd_sha}", "kamal"
      FileUtils.mkdir_p build_directory
      FileUtils.touch File.join build_directory, "Dockerfile"
      yield build_directory + "/"
    ensure
      FileUtils.rm_rf build_directory
    end

    def pwd_sha
      Digest::SHA256.hexdigest(Dir.pwd)[0..12]
    end
end
