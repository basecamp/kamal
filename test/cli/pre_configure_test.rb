require_relative "cli_test_case"

class CliPreConfigureTest < CliTestCase
  teardown do
    ENV.delete("KAMAL_DESTINATION")
    ENV.delete("PRE_CONFIGURE_HOST")
  end

  test "rewrites the destination, saying so on stderr" do
    with_pre_configure_hook "KAMAL_DESTINATION=world" do
      stdout = nil
      stderr = stderred { stdout = run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml", "-d", "beta") }

      assert_equal "world", KAMAL.config.destination
      assert_match "Using destination world from the pre-configure hook", stderr
      assert_no_match "pre-configure", stdout
    end
  end

  test "sets a destination when none was given" do
    with_pre_configure_hook "KAMAL_DESTINATION=world" do
      run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml")

      assert_equal "world", KAMAL.config.destination
    end
  end

  test "keeps the destination when the hook writes none" do
    with_pre_configure_hook "# nothing to change", "", "KAMAL_DESTINATION=" do
      output = run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml", "-d", "world")

      assert_equal "world", KAMAL.config.destination
      assert_no_match "Using destination", output
    end
  end

  test "sets the variables it writes for the config" do
    with_pre_configure_hook "PRE_CONFIGURE_HOST=1.1.1.9" do
      File.write("config.yml", <<~YAML)
        service: app
        image: dhh/app
        registry:
          username: user
          password: pw
        builder:
          arch: amd64
        servers:
          - <%= ENV.fetch("PRE_CONFIGURE_HOST") %>
      YAML

      run_command("exec", "date", "-c", "config.yml")

      assert_equal [ "1.1.1.9" ], KAMAL.config.all_hosts
      assert_equal "1.1.1.9", ENV["PRE_CONFIGURE_HOST"]
    end
  end

  test "gets the destination and command, and not a destination left in the environment" do
    ENV["KAMAL_DESTINATION"] = "leaked"

    with_pre_configure_hook do
      run_command("exec", "date", "-c", "test/fixtures/deploy_with_accessories.yml")

      assert_nil @hook_env["KAMAL_DESTINATION"]
      assert_equal "server", @hook_env["KAMAL_COMMAND"]
      assert @hook_env["KAMAL_ENV"].present?
    end
  end

  test "gets the command when hosts are given" do
    with_pre_configure_hook do
      run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml", "-d", "world", "--hosts", "1.1.1.1")

      assert_equal "world", @hook_env["KAMAL_DESTINATION"]
      assert_equal "server", @hook_env["KAMAL_COMMAND"]
    end
  end

  test "gets the subcommand when run through main" do
    config = [ "-c", "test/fixtures/deploy_with_accessories.yml" ]
    [
      [ "server", "exec", "date", *config ],
      [ "server", "exec", "date", *config, "--hosts", "1.1.1.1" ],
      [ "server", "--hosts", "1.1.1.1", "exec", "date", *config ],
      [ "server", "--hosts", "1.1.1.1", "exe", "date", *config ]
    ].each do |argv|
      with_pre_configure_hook do
        SSHKit::Backend::Abstract.any_instance.stubs(:capture).with("date", strip: true, verbosity: 1).returns("Today")
        stdouted { Kamal::Cli::Main.start(argv) }

        assert_equal "server", @hook_env["KAMAL_COMMAND"]
        assert_equal "exec", @hook_env["KAMAL_SUBCOMMAND"], "for #{argv.join(" ")}"
      end
      KAMAL.reset
    end
  end

  test "runs once" do
    with_pre_configure_hook do
      run_command("exec", "date", "-c", "test/fixtures/deploy_with_accessories.yml")
      KAMAL.config

      assert_equal 1, @hook_runs
    end
  end

  test "runs before an alias is looked up, and again for the command it expands to" do
    with_pre_configure_hook "KAMAL_DESTINATION=world" do
      with_argv([ "info", "-c", "test/fixtures/deploy_for_required_dest.yml" ]) do
        File.write("test/fixtures/deploy_for_required_dest.world.yml", "aliases:\n  info: config\n", mode: "a")

        stdouted { Kamal::Cli::Main.start }
        assert_equal "world", KAMAL.config.destination
      end

      # Named for the alias to look it up, so a hook can leave side effects to the commands it knows
      assert_equal [ "info", "config" ], @hook_commands
    end
  end

  test "fails on an invalid output line" do
    with_pre_configure_hook "KAMAL_DESTINATION=world", "export FOO=bar" do
      error = assert_raises(Kamal::Cli::HookError) do
        run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml")
      end

      assert_match "invalid line 2", error.message
    end
  end

  test "fails on a NUL in a value, before setting anything" do
    with_pre_configure_hook "PRE_CONFIGURE_HOST=1.1.1.9", "KAMAL_DESTINATION=wor\0ld" do
      error = assert_raises(Kamal::Cli::HookError) do
        run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml")
      end

      assert_match "invalid line 2", error.message
      assert_nil ENV["PRE_CONFIGURE_HOST"]
    end
  end

  test "sets a value that isn't UTF-8 as written" do
    with_pre_configure_hook "PRE_CONFIGURE_HOST=caf\xE9" do
      run_command("exec", "date", "-c", "test/fixtures/deploy_with_accessories.yml")

      assert_equal "caf\xE9".b, ENV["PRE_CONFIGURE_HOST"].b
    end
  end

  test "failure raises a hook error" do
    with_pre_configure_hook do
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with(".kamal/hooks/pre-configure")
        .raises(SSHKit::Command::Failed.new("beta3 is leased"))

      error = assert_raises(Kamal::Cli::HookError) do
        run_command("exec", "date", "-c", "test/fixtures/deploy_with_accessories.yml")
      end

      assert_match "beta3 is leased", error.message
    end
  end

  test "skipped with --skip-hooks" do
    with_pre_configure_hook "KAMAL_DESTINATION=world" do
      run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml", "-d", "world", "--skip-hooks")

      assert_equal 0, @hook_runs
    end
  end

  test "not run by commands that don't load the config" do
    with_pre_configure_hook do
      stdouted { Kamal::Cli::Main.start([ "version" ]) }

      assert_equal 0, @hook_runs
    end
  end

  test "not run without a hook" do
    Dir.mktmpdir do |tmpdir|
      copy_fixtures(tmpdir)

      Dir.chdir(tmpdir) do
        SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        SSHKit::Backend::Abstract.any_instance.expects(:execute).with(".kamal/hooks/pre-configure").never

        run_command("exec", "date", "-c", "test/fixtures/deploy_for_required_dest.yml", "-d", "world")
        assert_equal "world", KAMAL.config.destination
      end
    end
  end

  private
    def run_command(*command)
      SSHKit::Backend::Abstract.any_instance.stubs(:capture).with("date", strip: true, verbosity: 1).returns("Today")

      stdouted { Kamal::Cli::Server.start(command) }
    end

    # The Printer backend doesn't run commands, so stand in for the hook:
    # record the env it would get and write its output
    def with_pre_configure_hook(*output_lines)
      @hook_runs = 0
      @hook_commands = []

      Dir.mktmpdir do |tmpdir|
        copy_fixtures(tmpdir)

        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p(".kamal/hooks")
          FileUtils.touch(".kamal/hooks/pre-configure")

          SSHKit::Backend::Abstract.any_instance.stubs(:execute).with do |*args|
            if args == [ ".kamal/hooks/pre-configure" ]
              @hook_runs += 1
              @hook_commands << ENV["KAMAL_COMMAND"]
              @hook_env = ENV.to_h
              File.write(ENV["KAMAL_ENV"], output_lines.map { |line| "#{line}\n" }.join)
            end

            true
          end

          yield
        end
      end
    end
end
