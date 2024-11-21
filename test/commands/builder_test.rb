require "test_helper"

class CommandsBuilderTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], builder: { "arch" => "amd64" } }
  end

  test "target linux/amd64 locally by default" do
    builder = new_builder_command(builder: { "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target specified arch locally by default" do
    builder = new_builder_command(builder: { "arch" => [ "amd64" ] })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "build with caching" do
    builder = new_builder_command(builder: { "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "hybrid build if remote is set and building multiarch" do
    builder = new_builder_command(builder: { "arch" => [ "amd64", "arm64" ], "remote" => "ssh://app@127.0.0.1", "cache" => { "type" => "gha" } })
    assert_equal "hybrid", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder kamal-hybrid-docker-container-ssh---app-127-0-0-1 -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "remote build if remote is set and local disabled" do
    builder = new_builder_command(builder: { "arch" => [ "amd64", "arm64" ], "remote" => "ssh://app@127.0.0.1", "cache" => { "type" => "gha" }, "local" => false })
    assert_equal "remote", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder kamal-remote-ssh---app-127-0-0-1 -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target remote when remote set and arch is non local" do
    builder = new_builder_command(builder: { "arch" => [ "#{remote_arch}" ], "remote" => "ssh://app@host", "cache" => { "type" => "gha" } })
    assert_equal "remote", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/#{remote_arch} --builder kamal-remote-ssh---app-host -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target local when remote set and arch is local" do
    builder = new_builder_command(builder: { "arch" => [ "#{local_arch}" ], "remote" => "ssh://app@host", "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/#{local_arch} --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile",
      builder.target.build_options.join(" ")
  end

  test "build secrets" do
    with_test_secrets("secrets" => "token_a=foo\ntoken_b=bar") do
      FileUtils.touch("Dockerfile")
      builder = new_builder_command(builder: { "secrets" => [ "token_a", "token_b" ] })
      assert_equal \
        "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --secret id=\"token_a\" --secret id=\"token_b\" --file Dockerfile",
        builder.target.build_options.join(" ")
    end
  end

  test "build dockerfile" do
    Pathname.any_instance.expects(:exist?).returns(true).once
    builder = new_builder_command(builder: { "dockerfile" => "Dockerfile.xyz" })
    assert_equal \
      "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile.xyz",
      builder.target.build_options.join(" ")
  end

  test "missing dockerfile" do
    Pathname.any_instance.expects(:exist?).returns(false).once
    builder = new_builder_command(builder: { "dockerfile" => "Dockerfile.xyz" })
    assert_raises(Kamal::Commands::Builder::Base::BuilderError) do
      builder.target.build_options.join(" ")
    end
  end

  test "build target" do
    builder = new_builder_command(builder: { "target" => "prod" })
    assert_equal \
      "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --target prod",
      builder.target.build_options.join(" ")
  end

  test "build context" do
    builder = new_builder_command(builder: { "context" => ".." })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ..",
      builder.push.join(" ")
  end

  test "push with build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "push with build secrets" do
    with_test_secrets("secrets" => "a=foo\nb=bar") do
      FileUtils.touch("Dockerfile")
      builder = new_builder_command(builder: { "secrets" => [ "a", "b" ] })
      assert_equal \
        "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --secret id=\"a\" --secret id=\"b\" --file Dockerfile .",
        builder.push.join(" ")
    end
  end

  test "build with ssh agent socket" do
    builder = new_builder_command(builder: { "ssh" => "default=$SSH_AUTH_SOCK" })

    assert_equal \
      "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --ssh default=$SSH_AUTH_SOCK",
      builder.target.build_options.join(" ")
  end

  test "validate image" do
    assert_equal "docker inspect -f '{{ .Config.Labels.service }}' dhh/app:123 | grep -x app || (echo \"Image dhh/app:123 is missing the 'service' label\" && exit 1)", new_builder_command.validate_image.join(" ")
  end

  test "context build" do
    builder = new_builder_command(builder: { "context" => "./foo" })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ./foo",
      builder.push.join(" ")
  end

  test "push with provenance" do
    builder = new_builder_command(builder: { "provenance" => "mode=max" })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --provenance mode=max .",
      builder.push.join(" ")
  end

  test "push with provenance false" do
    builder = new_builder_command(builder: { "provenance" => false })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --provenance false .",
      builder.push.join(" ")
  end

  test "push with sbom" do
    builder = new_builder_command(builder: { "sbom" => true })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --sbom true .",
      builder.push.join(" ")
  end

  test "push with sbom false" do
    builder = new_builder_command(builder: { "sbom" => false })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --sbom false .",
      builder.push.join(" ")
  end

  test "mirror count" do
    command = new_builder_command
    assert_equal "docker info --format '{{index .RegistryConfig.Mirrors 0}}'", command.first_mirror.join(" ")
  end

  test "clone path with spaces" do
    command = new_builder_command
    Kamal::Git.stubs(:root).returns("/absolute/path with spaces")
    clone_command = command.clone.join(" ")
    clone_reset_commands = command.clone_reset_steps.map { |a| a.join(" ") }

    assert_match(%r{path\\ with\\ space}, clone_command)
    assert_no_match(%r{path with spaces}, clone_command)

    clone_reset_commands.each do |command|
      assert_match(%r{path\\ with\\ space}, command)
      assert_no_match(%r{path with spaces}, command)
    end
  end

  private
    def new_builder_command(additional_config = {})
      Kamal::Commands::Builder.new(Kamal::Configuration.new(@config.deep_merge(additional_config), version: "123"))
    end

    def local_arch
      Kamal::Utils.docker_arch
    end

    def remote_arch
      Kamal::Utils.docker_arch == "arm64" ? "amd64" : "arm64"
    end
end
