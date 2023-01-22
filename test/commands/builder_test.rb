require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/builder"

class CommandsBuilderTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
  end

  test "target multiarch by default" do
    builder = new_builder_command
    assert_equal "multiarch", builder.name
    assert_equal [:docker, :buildx, :build, "--push", "--platform linux/amd64,linux/arm64", "-t", "dhh/app:123", "."], builder.push
  end

  test "target native when multiarch is off" do
    builder = new_builder_command(builder: { "multiarch" => false })
    assert_equal "native", builder.name
    assert_equal [:docker, :build, "-t", "dhh/app:123", ".", "&&", :docker, :push, "dhh/app:123"], builder.push
  end

  test "target multiarch remote when local and remote is set" do
    builder = new_builder_command(builder: { "local" => { }, "remote" => { } })
    assert_equal "multiarch/remote", builder.name
    assert_equal [:docker, :buildx, :build, "--push", "--platform linux/amd64,linux/arm64", "-t", "dhh/app:123", "."], builder.push
  end

  test "target native remote when only remote is set" do
    builder = new_builder_command(builder: { "remote" => { "arch" => "amd64" } })
    assert_equal "native/remote", builder.name
    assert_equal [:docker, :buildx, :build, "--push", "--platform", "linux/amd64", "-t", "dhh/app:123", "."], builder.push
  end

  test "build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal [ "--build-arg", "a=1", "--build-arg", "b=2" ], builder.target.build_args
  end

  test "build secrets" do
    builder = new_builder_command(builder: { "secrets" => ["token_a", "token_b"] })
    assert_equal [ "--secret", "id=token_a", "--secret", "id=token_b" ], builder.target.build_secrets
  end

  test "native push with build args" do
    builder = new_builder_command(builder: { "multiarch" => false, "args" => { "a" => 1, "b" => 2 } })
    assert_equal [ :docker, :build, "-t", "--build-arg", "a=1", "--build-arg", "b=2", "dhh/app:123", ".", "&&", :docker, :push, "dhh/app:123" ], builder.push
  end

  test "multiarch push with build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal [ :docker, :buildx, :build, "--push", "--platform linux/amd64,linux/arm64", "-t", "dhh/app:123", "--build-arg", "a=1", "--build-arg", "b=2", "." ], builder.push
  end

  test "native push with with build secrets" do
    builder = new_builder_command(builder: { "multiarch" => false, "secrets" => [ "a", "b" ] })
    assert_equal [ :docker, :build, "-t", "--secret", "id=a", "--secret", "id=b", "dhh/app:123", ".", "&&", :docker, :push, "dhh/app:123" ], builder.push
  end

  private
    def new_builder_command(additional_config = {})
      Mrsk::Commands::Builder.new(Mrsk::Configuration.new(@config.merge(additional_config), version: "123"))
    end
end
