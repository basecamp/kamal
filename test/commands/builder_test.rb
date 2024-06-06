require "test_helper"

class CommandsBuilderTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
  end

  test "target multiarch by default" do
    builder = new_builder_command(builder: { "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder kamal-local -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target native when multiarch is off" do
    builder = new_builder_command(builder: { "multiarch" => false })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target native cached when multiarch is off and cache is set" do
    builder = new_builder_command(builder: { "multiarch" => false, "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --builder kamal-local -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target multiarch remote when local and remote is set" do
    builder = new_builder_command(builder: { "local" => { "arch" => "arm64" }, "remote" => { "arch" => "amd64", "host" => "ssh://app@127.0.0.1" }, "cache" => { "type" => "gha" } })
    assert_equal "hybrid", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/arm64,linux/amd64 --builder kamal-hybrid-arm64-amd64-ssh---app-127-0-0-1 -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target multiarch local when arch is set" do
    builder = new_builder_command(builder: { "local" => { "arch" => "amd64" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target native remote when only remote is set" do
    builder = new_builder_command(builder: { "remote" => { "arch" => "amd64", "host" => "ssh://app@host" }, "cache" => { "type" => "gha" } })
    assert_equal "remote", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-remote-amd64-ssh---app-host -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile",
      builder.target.build_options.join(" ")
  end

  test "build secrets" do
    builder = new_builder_command(builder: { "secrets" => [ "token_a", "token_b" ] })
    assert_equal \
      "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --secret id=\"token_a\" --secret id=\"token_b\" --file Dockerfile",
      builder.target.build_options.join(" ")
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
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ..",
      builder.push.join(" ")
  end

  test "native push with build args" do
    builder = new_builder_command(builder: { "multiarch" => false, "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "docker buildx build --push --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "multiarch push with build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "native push with build secrets" do
    builder = new_builder_command(builder: { "multiarch" => false, "secrets" => [ "a", "b" ] })
    assert_equal \
      "docker buildx build --push --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --secret id=\"a\" --secret id=\"b\" --file Dockerfile .",
      builder.push.join(" ")
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

  test "multiarch context build" do
    builder = new_builder_command(builder: { "context" => "./foo" })
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ./foo",
      builder.push.join(" ")
  end

  test "native context build" do
    builder = new_builder_command(builder: { "multiarch" => false, "context" => "./foo" })
    assert_equal \
      "docker buildx build --push --builder kamal-local -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ./foo",
      builder.push.join(" ")
  end

  test "cached context build" do
    builder = new_builder_command(builder: { "multiarch" => false, "context" => "./foo", "cache" => { "type" => "gha" } })
    assert_equal \
      "docker buildx build --push --builder kamal-local -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile ./foo",
      builder.push.join(" ")
  end

  test "remote context build" do
    builder = new_builder_command(builder: { "remote" => { "arch" => "amd64", "host" => "ssh://app@host" }, "context" => "./foo" })
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder kamal-remote-amd64-ssh---app-host -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ./foo",
      builder.push.join(" ")
  end

  test "mirror count" do
    command = new_builder_command
    assert_equal "docker info --format '{{index .RegistryConfig.Mirrors 0}}'", command.first_mirror.join(" ")
  end

  private
    def new_builder_command(additional_config = {})
      Kamal::Commands::Builder.new(Kamal::Configuration.new(@config.merge(additional_config), version: "123"))
    end

    def build_directory
      "#{Dir.tmpdir}/kamal-clones/app/kamal/"
    end
end
