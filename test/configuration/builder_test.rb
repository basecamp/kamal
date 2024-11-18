require "test_helper"

class ConfigurationBuilderTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" }, servers: [ "1.1.1.1" ]
    }
  end

  test "local?" do
    assert_equal true, config.builder.local?
  end

  test "remote?" do
    assert_equal false, config.builder.remote?
  end

  test "remote" do
    assert_nil config.builder.remote
  end

  test "setting both local and remote configs" do
    @deploy[:builder] = {
      "arch" => [ "amd64", "arm64" ],
      "remote" => "ssh://root@192.168.0.1"
    }

    assert_equal true, config.builder.local?
    assert_equal true, config.builder.remote?

    assert_equal [ "amd64", "arm64" ], config.builder.arches
    assert_equal "ssh://root@192.168.0.1", config.builder.remote
  end

  test "cached?" do
    assert_equal false, config.builder.cached?
  end

  test "invalid cache type specified" do
    @deploy[:builder]["cache"] = { "type" => "invalid" }

    assert_raises(Kamal::ConfigurationError) do
      config.builder
    end
  end

  test "cache_from" do
    assert_nil config.builder.cache_from
  end

  test "cache_to" do
    assert_nil config.builder.cache_to
  end

  test "setting gha cache" do
    @deploy[:builder] = { "arch" => "amd64", "cache" => { "type" => "gha", "options" => "mode=max" } }

    assert_equal "type=gha", config.builder.cache_from
    assert_equal "type=gha,mode=max", config.builder.cache_to
  end

  test "setting registry cache" do
    @deploy[:builder] = { "arch" => "amd64", "cache" => { "type" => "registry", "options" => "mode=max,image-manifest=true,oci-mediatypes=true" } }

    assert_equal "type=registry,ref=dhh/app-build-cache", config.builder.cache_from
    assert_equal "type=registry,ref=dhh/app-build-cache,mode=max,image-manifest=true,oci-mediatypes=true", config.builder.cache_to
  end

  test "setting registry cache when using a custom registry" do
    @deploy[:registry]["server"] = "registry.example.com"
    @deploy[:builder] = { "arch" => "amd64", "cache" => { "type" => "registry", "options" => "mode=max,image-manifest=true,oci-mediatypes=true" } }

    assert_equal "type=registry,ref=registry.example.com/dhh/app-build-cache", config.builder.cache_from
    assert_equal "type=registry,ref=registry.example.com/dhh/app-build-cache,mode=max,image-manifest=true,oci-mediatypes=true", config.builder.cache_to
  end

  test "setting registry cache with image" do
    @deploy[:builder] = { "arch" => "amd64", "cache" => { "type" => "registry", "image" => "kamal", "options" => "mode=max" } }

    assert_equal "type=registry,ref=kamal", config.builder.cache_from
    assert_equal "type=registry,ref=kamal,mode=max", config.builder.cache_to
  end

  test "args" do
    assert_equal({}, config.builder.args)
  end

  test "setting args" do
    @deploy[:builder]["args"] = { "key" => "value" }

    assert_equal({ "key" => "value" }, config.builder.args)
  end

  test "secrets" do
    assert_equal({}, config.builder.secrets)
  end

  test "setting secrets" do
    with_test_secrets("secrets" => "GITHUB_TOKEN=secret123") do
      @deploy[:builder]["secrets"] = [ "GITHUB_TOKEN" ]

      assert_equal({ "GITHUB_TOKEN" => "secret123" }, config.builder.secrets)
    end
  end

  test "dockerfile" do
    assert_equal "Dockerfile", config.builder.dockerfile
  end

  test "setting dockerfile" do
    @deploy[:builder]["dockerfile"] = "Dockerfile.dev"

    assert_equal "Dockerfile.dev", config.builder.dockerfile
  end

  test "context" do
    assert_equal ".", config.builder.context
  end

  test "setting context" do
    @deploy[:builder]["context"] = ".."

    assert_equal "..", config.builder.context
  end

  test "ssh" do
    assert_nil config.builder.ssh
  end

  test "setting ssh params" do
    @deploy[:builder]["ssh"] = "default=$SSH_AUTH_SOCK"

    assert_equal "default=$SSH_AUTH_SOCK", config.builder.ssh
  end

  test "provenance" do
    assert_nil config.builder.provenance
  end

  test "setting provenance" do
    @deploy[:builder]["provenance"] = "mode=max"

    assert_equal "mode=max", config.builder.provenance
  end

  test "sbom" do
    assert_nil config.builder.sbom
  end

  test "setting sbom" do
    @deploy[:builder]["sbom"] = true

    assert_equal true, config.builder.sbom
  end

  test "local disabled but no remote set" do
    @deploy[:builder]["local"] = false

    assert_raises(Kamal::ConfigurationError) do
      config.builder
    end
  end

  test "local disabled all arches are remote" do
    @deploy[:builder]["local"] = false
    @deploy[:builder]["remote"] = "ssh://root@192.168.0.1"
    @deploy[:builder]["arch"] = [ "amd64", "arm64" ]

    assert_equal [], config.builder.local_arches
    assert_equal [ "amd64", "arm64" ], config.builder.remote_arches
  end

  private
    def config
      Kamal::Configuration.new(@deploy)
    end
end
