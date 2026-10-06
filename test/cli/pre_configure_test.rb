require_relative "cli_test_case"

class CliPreConfigureTest < CliTestCase
  test "pre-configure hook can rewrite destination" do
    with_pre_configure_hook({ "KAMAL_DESTINATION" => "world" }) do
      # Pass -d beta, but the hook rewrites to "world"
      run_command("exec", "date", "-c", config_file_path("deploy_for_required_dest"), "-d", "beta")

      assert_equal "world", KAMAL.config.destination
    end
  end

  test "pre-configure hook can inject destination when require_destination is set" do
    with_pre_configure_hook({ "KAMAL_DESTINATION" => "world" }) do
      # No -d flag, but the hook injects one — should not raise despite require_destination: true
      run_command("exec", "date", "-c", config_file_path("deploy_for_required_dest"))

      assert_equal "world", KAMAL.config.destination
    end
  end

  test "pre-configure hook prints KAMAL_MESSAGE" do
    with_pre_configure_hook({ "KAMAL_MESSAGE" => "Deploying to beta2" }) do
      output = run_command("exec", "date", "-c", config_file_path("deploy_with_accessories"))

      assert_match "Deploying to beta2", output
    end
  end

  test "pre-configure hook accumulates output for subsequent hooks" do
    with_pre_configure_hook({ "DEPLOY_SLOT" => "slot3" }) do
      run_command("exec", "date", "-c", config_file_path("deploy_with_accessories"))

      assert_equal "slot3", KAMAL.hook_outputs["DEPLOY_SLOT"]
    end
  end

  test "pre-configure hook failure raises HookError" do
    with_pre_configure_hook_that_fails do
      assert_raises(Kamal::Cli::HookError) do
        run_command("exec", "date", "-c", config_file_path("deploy_with_accessories"))
      end
    end
  end

  test "pre-configure hook tempfile is cleaned up on failure" do
    tempfile_paths = []
    original_new = Kamal::HookOutput.method(:new)

    Kamal::HookOutput.stubs(:new).returns(original_new.call.tap { |ho| tempfile_paths << ho.path })

    with_pre_configure_hook_that_fails do
      assert_raises(Kamal::Cli::HookError) do
        run_command("exec", "date", "-c", config_file_path("deploy_with_accessories"))
      end
    end

    tempfile_paths.each { |path| refute File.exist?(path), "Tempfile #{path} should have been cleaned up" }
  end

  test "pre-configure hook is skipped with --skip-hooks" do
    with_pre_configure_hook({ "KAMAL_DESTINATION" => "world" }) do
      run_command("exec", "date", "-c", config_file_path("deploy_with_accessories"), "-H")

      assert_nil KAMAL.config.destination
    end
  end

  test "pre-configure hook does not fire for commands that skip config" do
    with_pre_configure_hook_that_fails do
      # version never accesses KAMAL.config, so the hook should not fire
      output = stdouted { Kamal::Cli::Main.start([ "version", "-c", config_file_path("deploy_with_accessories") ]) }
      assert_equal Kamal::VERSION, output
    end
  end

  test "pre-configure hook clears KAMAL_DESTINATION when no -d flag is passed" do
    ENV["KAMAL_DESTINATION"] = "leaked"

    with_pre_configure_hook({}) do
      run_command("exec", "date", "-c", config_file_path("deploy_with_accessories"))

      assert_nil KAMAL.config.destination
    end
  ensure
    ENV.delete("KAMAL_DESTINATION")
  end

  test "pre-configure hook ignores empty KAMAL_DESTINATION from hook" do
    with_pre_configure_hook({ "KAMAL_DESTINATION" => "" }) do
      run_command("exec", "date", "-c", config_file_path("deploy_with_accessories"))

      assert_nil KAMAL.config.destination
    end
  end

  private
    def run_command(*command)
      SSHKit::Backend::Abstract.any_instance.stubs(:capture)
        .with("date", strip: true, verbosity: 1)
        .returns("Today")

      stdouted { Kamal::Cli::Server.start(command) }
    end

    def config_file_path(fixture_name)
      "test/fixtures/#{fixture_name}.yml"
    end

    def with_pre_configure_hook(output)
      Dir.mktmpdir do |tmpdir|
        original_pwd = Dir.pwd
        old_dest = ENV["KAMAL_DESTINATION"]
        begin
          copy_fixtures(tmpdir)

          hook_dir = File.join(tmpdir, ".kamal", "hooks")
          FileUtils.mkdir_p(hook_dir)
          File.write(File.join(hook_dir, "pre-configure"), "#!/bin/bash\n")

          Dir.chdir(tmpdir)

          # Stub parse to return desired output since Printer backend won't run the hook
          Kamal::HookOutput.any_instance.stubs(:parse).returns(output)

          yield
        ensure
          ENV["KAMAL_DESTINATION"] = old_dest
          Dir.chdir(original_pwd)
        end
      end
    end

    def with_pre_configure_hook_that_fails
      Dir.mktmpdir do |tmpdir|
        original_pwd = Dir.pwd
        begin
          copy_fixtures(tmpdir)

          hook_dir = File.join(tmpdir, ".kamal", "hooks")
          FileUtils.mkdir_p(hook_dir)
          File.write(File.join(hook_dir, "pre-configure"), "#!/bin/bash\nexit 1")

          Dir.chdir(tmpdir)

          SSHKit::Backend::Abstract.any_instance.stubs(:execute)
            .with { |*args| args.first.to_s.include?("pre-configure") }
            .raises(SSHKit::Command::Failed.new("hook failed"))

          yield
        ensure
          Dir.chdir(original_pwd)
        end
      end
    end
end
