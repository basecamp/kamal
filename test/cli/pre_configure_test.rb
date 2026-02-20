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

  test "pre-configure hook falls back to default hooks_path on config ERB error" do
    Tempfile.create([ "deploy", ".yml" ]) do |config_file|
      config_file.write(<<~YAML)
        service: app
        image: dhh/app
        hooks_path: '<%= ENV.fetch("NONEXISTENT_VAR_FOR_TEST") %>'
      YAML
      config_file.flush

      cli = Kamal::Cli::Base.allocate
      result = cli.send(:pre_configure_hooks_path, config_file.path, {})
      assert_equal ".kamal/hooks", result
    end
  end

  test "pre-configure hook honors destination-aware hooks_path" do
    hooks_path = '.kamal/hooks-<%= ENV["KAMAL_DESTINATION"] %>'
    with_pre_configure_hook({ "KAMAL_DESTINATION" => "world" }, hooks_path: hooks_path, destination: "beta") do
      run_command("exec", "date", "-c", "config/deploy.yml", "-d", "beta")

      assert_equal "world", KAMAL.config.destination
    end
  end

  private
    def run_command(*command)
      SSHKit::Backend::Abstract.any_instance.stubs(:capture)
        .with("date", verbosity: 1)
        .returns("Today")

      stdouted { Kamal::Cli::Server.start(command) }
    end

    def config_file_path(fixture_name)
      "test/fixtures/#{fixture_name}.yml"
    end

    def with_pre_configure_hook(output, hooks_path: nil, destination: nil)
      Dir.mktmpdir do |tmpdir|
        original_pwd = Dir.pwd
        old_dest = ENV["KAMAL_DESTINATION"]
        begin
          copy_fixtures(tmpdir)

          # Resolve ERB hooks_path to determine the actual directory on disk
          resolved_hooks_path = if hooks_path && destination
            ENV["KAMAL_DESTINATION"] = destination
            ERB.new(hooks_path).result
          else
            hooks_path || ".kamal/hooks"
          end

          hook_dir = File.join(tmpdir, resolved_hooks_path)
          FileUtils.mkdir_p(hook_dir)
          File.write(File.join(hook_dir, "pre-configure"), "#!/bin/bash\n")

          # If custom hooks_path, write a config that uses it (with raw ERB intact),
          # plus a destination overlay so config loads successfully after rewrite
          if hooks_path
            config_dir = File.join(tmpdir, "config")
            FileUtils.mkdir_p(config_dir)
            File.write(File.join(config_dir, "deploy.yml"), <<~YAML)
              service: app
              image: dhh/app
              registry:
                username: dhh
                password: secret
              servers:
                - 1.1.1.1
              builder:
                arch: amd64
              hooks_path: '#{hooks_path}'
            YAML

            # Create destination overlay for the rewritten destination
            rewritten_dest = output["KAMAL_DESTINATION"]
            if rewritten_dest
              File.write(File.join(config_dir, "deploy.#{rewritten_dest}.yml"), <<~YAML)
                servers:
                  - 1.1.1.1
              YAML
            end
          end

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
