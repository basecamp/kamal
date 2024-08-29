require "test_helper"

class ConfigurationBuilderTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1" ]
    }

    @deploy_with_builder_option = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1" ],
      builder: {}
    }
  end

  test "multiarch?" do
    assert_equal true, config.builder.multiarch?
  end

  test "setting multiarch to false" do
    @deploy_with_builder_option[:builder] = { "multiarch" => false }

    assert_equal false, config_with_builder_option.builder.multiarch?
  end

  test "local?" do
    assert_equal false, config.builder.local?
  end

  test "remote?" do
    assert_equal false, config.builder.remote?
  end

  test "remote_arch" do
    assert_nil config.builder.remote_arch
  end

  test "remote_host" do
    assert_nil config.builder.remote_host
  end

  test "setting both local and remote configs" do
    @deploy_with_builder_option[:builder] = {
      "local" => { "arch" => "arm64", "host" => "unix:///Users/<%= `whoami`.strip %>/.docker/run/docker.sock" },
      "remote" => { "arch" => "amd64", "host" => "ssh://root@192.168.0.1" }
    }

    assert_equal true, config_with_builder_option.builder.local?
    assert_equal true, config_with_builder_option.builder.remote?

    assert_equal "amd64", config_with_builder_option.builder.remote_arch
    assert_equal "ssh://root@192.168.0.1", config_with_builder_option.builder.remote_host

    assert_equal "arm64", config_with_builder_option.builder.local_arch
    assert_equal "unix:///Users/<%= `whoami`.strip %>/.docker/run/docker.sock", config_with_builder_option.builder.local_host
  end

  test "cached?" do
    assert_equal false, config.builder.cached?
  end

  test "invalid cache type specified" do
    @deploy_with_builder_option[:builder] = { "cache" => { "type" => "invalid" } }

    assert_raises(Kamal::ConfigurationError) do
      config_with_builder_option.builder
    end
  end

  test "cache_from" do
    assert_nil config.builder.cache_from
  end

  test "cache_to" do
    assert_nil config.builder.cache_to
  end

  test "setting gha cache" do
    @deploy_with_builder_option[:builder] = { "cache" => { "type" => "gha", "options" => "mode=max" } }

    assert_equal "type=gha", config_with_builder_option.builder.cache_from
    assert_equal "type=gha,mode=max", config_with_builder_option.builder.cache_to
  end

  test "setting registry cache" do
    @deploy_with_builder_option[:builder] = { "cache" => { "type" => "registry", "options" => "mode=max,image-manifest=true,oci-mediatypes=true" } }

    assert_equal "type=registry,ref=dhh/app-build-cache", config_with_builder_option.builder.cache_from
    assert_equal "type=registry,mode=max,image-manifest=true,oci-mediatypes=true,ref=dhh/app-build-cache", config_with_builder_option.builder.cache_to
  end

  test "setting registry cache when using a custom registry" do
    @deploy_with_builder_option[:registry]["server"] = "registry.example.com"
    @deploy_with_builder_option[:builder] = { "cache" => { "type" => "registry", "options" => "mode=max,image-manifest=true,oci-mediatypes=true" } }

    assert_equal "type=registry,ref=registry.example.com/dhh/app-build-cache", config_with_builder_option.builder.cache_from
    assert_equal "type=registry,mode=max,image-manifest=true,oci-mediatypes=true,ref=registry.example.com/dhh/app-build-cache", config_with_builder_option.builder.cache_to
  end

  test "setting registry cache with image" do
    @deploy_with_builder_option[:builder] = { "cache" => { "type" => "registry", "image" => "kamal", "options" => "mode=max" } }

    assert_equal "type=registry,ref=kamal", config_with_builder_option.builder.cache_from
    assert_equal "type=registry,mode=max,ref=kamal", config_with_builder_option.builder.cache_to
  end

  test "args" do
    assert_equal({}, config.builder.args)
  end

  test "setting args" do
    @deploy_with_builder_option[:builder] = { "args" => { "key" => "value" } }

    assert_equal({ "key" => "value" }, config_with_builder_option.builder.args)
  end

  test "secrets" do
    assert_equal [], config.builder.secrets
  end

  test "setting secrets" do
    @deploy_with_builder_option[:builder] = { "secrets" => [ "GITHUB_TOKEN" ] }

    assert_equal [ "GITHUB_TOKEN" ], config_with_builder_option.builder.secrets
  end

  test "dockerfile" do
    assert_equal "Dockerfile", config.builder.dockerfile
  end

  test "setting dockerfile" do
    @deploy_with_builder_option[:builder] = { "dockerfile" => "Dockerfile.dev" }

    assert_equal "Dockerfile.dev", config_with_builder_option.builder.dockerfile
  end

  test "context" do
    assert_equal ".", config.builder.context
  end

  test "setting context" do
    @deploy_with_builder_option[:builder] = { "context" => ".." }

    assert_equal "..", config_with_builder_option.builder.context
  end

  test "ssh" do
    assert_nil config.builder.ssh
  end

  test "setting ssh params" do
    @deploy_with_builder_option[:builder] = { "ssh" => "default=$SSH_AUTH_SOCK" }

    assert_equal "default=$SSH_AUTH_SOCK", config_with_builder_option.builder.ssh
  end

  private
    def config
      Kamal::Configuration.new(@deploy)
    end

    def config_with_builder_option
      Kamal::Configuration.new(@deploy_with_builder_option)
    end
end
