require "test_helper"

class CommandsBuilderTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
  end

  test "target multiarch by default" do
    builder = new_builder_command
    assert_equal "multiarch", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder mrsk-app-multiarch -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target native when multiarch is off" do
    builder = new_builder_command(builder: { "multiarch" => false })
    assert_equal "native", builder.name
    assert_equal \
      "docker build -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile . && docker push dhh/app:123 && docker push dhh/app:latest",
      builder.push.join(" ")
  end

  test "target multiarch remote when local and remote is set" do
    builder = new_builder_command(builder: { "local" => { }, "remote" => { } })
    assert_equal "multiarch/remote", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder mrsk-app-multiarch-remote -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "target native remote when only remote is set" do
    builder = new_builder_command(builder: { "remote" => { "arch" => "amd64" } })
    assert_equal "native/remote", builder.name
    assert_equal \
      "docker buildx build --push --platform linux/amd64 --builder mrsk-app-native-remote -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "-t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile",
      builder.target.build_options.join(" ")
  end

  test "build secrets" do
    builder = new_builder_command(builder: { "secrets" => ["token_a", "token_b"] })
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
    assert_raises(Mrsk::Commands::Builder::Base::BuilderError) do
      builder.target.build_options.join(" ")
    end
  end

  test "build context" do
    builder = new_builder_command(builder: { "context" => ".." })
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder mrsk-app-multiarch -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ..",
      builder.push.join(" ")
  end

  test "native push with build args" do
    builder = new_builder_command(builder: { "multiarch" => false, "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "docker build -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile . && docker push dhh/app:123 && docker push dhh/app:latest",
      builder.push.join(" ")
  end

  test "multiarch push with build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "docker buildx build --push --platform linux/amd64,linux/arm64 --builder mrsk-app-multiarch -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile .",
      builder.push.join(" ")
  end

  test "native push with build secrets" do
    builder = new_builder_command(builder: { "multiarch" => false, "secrets" => [ "a", "b" ] })
    assert_equal \
      "docker build -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --secret id=\"a\" --secret id=\"b\" --file Dockerfile . && docker push dhh/app:123 && docker push dhh/app:latest",
      builder.push.join(" ")
  end

  private
    def new_builder_command(additional_config = {})
      Mrsk::Commands::Builder.new(Mrsk::Configuration.new(@config.merge(additional_config), version: "123"))
    end
end
