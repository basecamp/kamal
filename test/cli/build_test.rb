require_relative "cli_test_case"

class CliBuildTest < CliTestCase
  test "deliver" do
    Kamal::Cli::Build.any_instance.expects(:push)
    Kamal::Cli::Build.any_instance.expects(:pull)

    run_command("deliver")
  end

  test "push" do
    with_build_directory do |build_directory|
      Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
      hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", command: "build", subcommand: "push" }

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :"rev-parse", :HEAD)
        .returns(Kamal::Git.revision)

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :status, "--porcelain")
        .returns("")

      run_command("push", "--verbose").tap do |output|
        assert_hook_ran "pre-build", output, **hook_variables
        assert_match /Cloning repo into build directory/, output
        assert_match /git -C #{Dir.tmpdir}\/kamal-clones\/app-#{pwd_sha} clone #{Dir.pwd}/, output
        assert_match /docker --version && docker buildx version/, output
        assert_match /docker buildx build --push --platform linux\/amd64 --builder kamal-local-docker-container -t dhh\/app:999 -t dhh\/app:latest --label service="app" --file Dockerfile \. as .*@localhost/, output
      end
    end
  end

  test "push resetting clone" do
    with_build_directory do |build_directory|
      stub_setup

      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "--version", "&&", :docker, :buildx, "version")

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:git, "-C", "#{Dir.tmpdir}/kamal-clones/app-#{pwd_sha}", :clone, Dir.pwd, "--recurse-submodules")
        .raises(SSHKit::Command::Failed.new("fatal: destination path 'kamal' already exists and is not an empty directory"))
        .then
        .returns(true)
      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:git, "-C", build_directory, :remote, "set-url", :origin, Dir.pwd)
      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:git, "-C", build_directory, :fetch, :origin)
      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:git, "-C", build_directory, :reset, "--hard", Kamal::Git.revision)
      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:git, "-C", build_directory, :clean, "-fdx")
      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:git, "-C", build_directory, :submodule, :update, "--init")

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:docker, :buildx, :build, "--push", "--platform", "linux/amd64", "--builder", "kamal-local-docker-container", "-t", "dhh/app:999", "-t", "dhh/app:latest", "--label", "service=\"app\"", "--file", "Dockerfile", ".")

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :"rev-parse", :HEAD)
        .returns(Kamal::Git.revision)

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :status, "--porcelain")
        .returns("")

      run_command("push", "--verbose").tap do |output|
        assert_match /Cloning repo into build directory/, output
        assert_match /Resetting local clone/, output
      end
    end
  end

  test "push without clone" do
    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", command: "build", subcommand: "push" }

    run_command("push", "--verbose", fixture: :without_clone).tap do |output|
      assert_no_match /Cloning repo into build directory/, output
      assert_hook_ran "pre-build", output, **hook_variables
      assert_match /docker --version && docker buildx version/, output
      assert_match /docker buildx build --push --platform linux\/amd64 --builder kamal-local-docker-container -t dhh\/app:999 -t dhh\/app:latest --label service="app" --file Dockerfile . as .*@localhost/, output
    end
  end

  test "push with corrupt clone" do
    with_build_directory do |build_directory|
      stub_setup

      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "--version", "&&", :docker, :buildx, "version")

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:git, "-C", "#{Dir.tmpdir}/kamal-clones/app-#{pwd_sha}", :clone, Dir.pwd, "--recurse-submodules")
        .raises(SSHKit::Command::Failed.new("fatal: destination path 'kamal' already exists and is not an empty directory"))
        .then
        .returns(true)
        .twice

      SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:git, "-C", build_directory, :remote, "set-url", :origin, Dir.pwd)
        .raises(SSHKit::Command::Failed.new("fatal: not a git repository"))

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :"rev-parse", :HEAD)
        .returns(Kamal::Git.revision)

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :status, "--porcelain")
        .returns("")

      Dir.stubs(:chdir)

      run_command("push", "--verbose") do |output|
        assert_match /Cloning repo into build directory `#{build_directory}`\.\.\..*Cloning repo into build directory `#{build_directory}`\.\.\./, output
        assert_match "Resetting local clone as `#{build_directory}` already exists...", output
        assert_match "Error preparing clone: Failed to clone repo: fatal: not a git repository, deleting and retrying...", output
      end
    end
  end

  test "push without builder" do
    with_build_directory do |build_directory|
      stub_setup

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:docker, "--version", "&&", :docker, :buildx, "version")

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:docker, :buildx, :rm, "kamal-local-docker-container")

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:docker, :buildx, :create, "--name", "kamal-local-docker-container", "--driver=docker-container")

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:docker, :buildx, :inspect, "kamal-local-docker-container")
        .raises(SSHKit::Command::Failed.new("no builder"))

      SSHKit::Backend::Abstract.any_instance.expects(:execute).with { |*args| args.first.start_with?("git") }

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :"rev-parse", :HEAD)
        .returns(Kamal::Git.revision)

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:git, "-C", anything, :status, "--porcelain")
        .returns("")

      SSHKit::Backend::Abstract.any_instance.expects(:execute)
        .with(:docker, :buildx, :build, "--push", "--platform", "linux/amd64", "--builder", "kamal-local-docker-container", "-t", "dhh/app:999", "-t", "dhh/app:latest", "--label", "service=\"app\"", "--file", "Dockerfile", ".")

      run_command("push").tap do |output|
        assert_match /WARN Missing compatible builder, so creating a new one first/, output
      end
    end
  end

  test "push with no buildx plugin" do
    stub_setup
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, "--version", "&&", :docker, :buildx, "version")
      .raises(SSHKit::Command::Failed.new("no buildx"))

    Kamal::Commands::Builder.any_instance.stubs(:native_and_local?).returns(false)
    assert_raises(Kamal::Cli::Build::BuildError) { run_command("push") }
  end

  test "push pre-build hook failure" do
    fail_hook("pre-build")

    error = assert_raises(Kamal::Cli::HookError) { run_command("push") }
    assert_equal "Hook `pre-build` failed:\nfailed", error.message

    assert @executions.none? { |args| args[0..2] == [ :docker, :build ] }
  end

  test "pull" do
    run_command("pull").tap do |output|
      assert_match /docker info --format '{{index .RegistryConfig.Mirrors 0}}'/, output
      assert_match /docker image rm --force dhh\/app:999/, output
      assert_match /docker pull dhh\/app:999/, output
      assert_match "docker inspect -f '{{ .Config.Labels.service }}' dhh/app:999 | grep -x app || (echo \"Image dhh/app:999 is missing the 'service' label\" && exit 1)", output
    end
  end

  test "pull with mirror" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :info, "--format '{{index .RegistryConfig.Mirrors 0}}'")
      .returns("registry-mirror.example.com")
      .at_least_once

    run_command("pull").tap do |output|
      assert_match /Pulling image on 1\.1\.1\.\d to seed the mirror\.\.\./, output
      assert_match "Pulling image on remaining hosts...", output
      assert_equal 4, output.scan(/docker pull dhh\/app:999/).size, output
      assert_match "docker inspect -f '{{ .Config.Labels.service }}' dhh/app:999 | grep -x app || (echo \"Image dhh/app:999 is missing the 'service' label\" && exit 1)", output
    end
  end

  test "pull with mirrors" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :info, "--format '{{index .RegistryConfig.Mirrors 0}}'")
      .returns("registry-mirror.example.com", "registry-mirror2.example.com")
      .at_least_once

    run_command("pull").tap do |output|
      assert_match /Pulling image on 1\.1\.1\.\d, 1\.1\.1\.\d to seed the mirrors\.\.\./, output
      assert_match "Pulling image on remaining hosts...", output
      assert_equal 4, output.scan(/docker pull dhh\/app:999/).size, output
      assert_match "docker inspect -f '{{ .Config.Labels.service }}' dhh/app:999 | grep -x app || (echo \"Image dhh/app:999 is missing the 'service' label\" && exit 1)", output
    end
  end

  test "create" do
    run_command("create").tap do |output|
      assert_match /docker buildx create --name kamal-local-docker-container --driver=docker-container/, output
    end
  end

  test "create remote" do
    run_command("create", fixture: :with_remote_builder).tap do |output|
      assert_match "Running /usr/bin/env true on 1.1.1.5", output
      assert_match "docker context create kamal-remote-ssh---app-1-1-1-5-context --description 'kamal-remote-ssh---app-1-1-1-5 host' --docker 'host=ssh://app@1.1.1.5'", output
      assert_match "docker buildx create --name kamal-remote-ssh---app-1-1-1-5 kamal-remote-ssh---app-1-1-1-5-context", output
    end
  end

  test "create remote with custom ports" do
    run_command("create", fixture: :with_remote_builder_and_custom_ports).tap do |output|
      assert_match "Running /usr/bin/env true on 1.1.1.5", output
      assert_match "docker context create kamal-remote-ssh---app-1-1-1-5-2122-context --description 'kamal-remote-ssh---app-1-1-1-5-2122 host' --docker 'host=ssh://app@1.1.1.5:2122'", output
      assert_match "docker buildx create --name kamal-remote-ssh---app-1-1-1-5-2122 kamal-remote-ssh---app-1-1-1-5-2122-context", output
    end
  end

  test "create hybrid" do
    run_command("create", fixture: :with_hybrid_builder).tap do |output|
      assert_match "Running /usr/bin/env true on 1.1.1.5", output
      assert_match "docker buildx create --platform linux/#{Kamal::Utils.docker_arch} --name kamal-hybrid-docker-container-ssh---app-1-1-1-5 --driver=docker-container", output
      assert_match "docker context create kamal-hybrid-docker-container-ssh---app-1-1-1-5-context --description 'kamal-hybrid-docker-container-ssh---app-1-1-1-5 host' --docker 'host=ssh://app@1.1.1.5'", output
      assert_match "docker buildx create --platform linux/#{Kamal::Utils.docker_arch == "amd64" ? "arm64" : "amd64"} --append --name kamal-hybrid-docker-container-ssh---app-1-1-1-5 kamal-hybrid-docker-container-ssh---app-1-1-1-5-context", output
    end
  end

  test "create with error" do
    stub_setup
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |arg| arg == :docker }
      .raises(SSHKit::Command::Failed.new("stderr=error"))

    run_command("create").tap do |output|
      assert_match /Couldn't create remote builder: error/, output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match /docker buildx rm kamal-local/, output
    end
  end

  test "details" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :context, :ls, "&&", :docker, :buildx, :ls)
      .returns("docker builder info")

    run_command("details").tap do |output|
      assert_match /Builder: local/, output
      assert_match /docker builder info/, output
    end
  end

  private
    def run_command(*command, fixture: :with_accessories)
      stdouted { Kamal::Cli::Build.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end

    def stub_dependency_checks
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with(:docker, "--version", "&&", :docker, :buildx, "version")
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| args[0..1] == [ :docker, :buildx ] }
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
