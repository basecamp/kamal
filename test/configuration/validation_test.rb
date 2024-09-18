require "test_helper"
class ConfigurationValidationTest < ActiveSupport::TestCase
  test "unknown root key" do
    assert_error "unknown key: unknown", unknown: "value"
    assert_error "unknown keys: unknown, unknown2", unknown: "value", unknown2: "value"
  end

  test "wrong root types" do
    [ :service, :image, :asset_path, :hooks_path, :primary_role, :minimum_version, :run_directory ].each do |key|
      assert_error "#{key}: should be a string", **{ key => [] }
    end

    [ :require_destination, :allow_empty_roles ].each do |key|
      assert_error "#{key}: should be a boolean", **{ key => "foo" }
    end

    [ :deploy_timeout, :drain_timeout, :retain_containers, :readiness_delay ].each do |key|
      assert_error "#{key}: should be an integer", **{ key => "foo" }
    end

    assert_error "volumes: should be an array", volumes: "foo"

    assert_error "servers: should be an array or a hash", servers: "foo"

    [ :labels, :registry, :accessories, :env, :ssh, :sshkit, :builder, :proxy, :boot, :logging ].each do |key|
      assert_error "#{key}: should be a hash", **{ key =>[] }
    end
  end

  test "servers" do
    assert_error "servers: should be an array or a hash", servers: "foo"
    assert_error "servers/0: should be a string or a hash", servers: [ [] ]
    assert_error "servers/0: multiple hosts found", servers: [ { "a" => "b", "c" => "d" } ]
    assert_error "servers/0/foo: should be a string or an array", servers: [ { "foo" => {} } ]
    assert_error "servers/0/foo/0: should be a string", servers: [ { "foo" => [ [] ] } ]
  end

  test "roles" do
    assert_error "servers/web: should be an array or a hash", servers: { "web" => "foo" }
    assert_error "servers/web/hosts: should be an array", servers: { "web" => { "hosts" => "" } }
    assert_error "servers/web/hosts/0: should be a string or a hash", servers: { "web" => { "hosts" => [ [] ] } }
    assert_error "servers/web/options: should be a hash", servers: { "web" => { "options" => "" } }
    assert_error "servers/web/logging/options: should be a hash", servers: { "web" => { "logging" => { "options" => "" } } }
    assert_error "servers/web/logging/driver: should be a string", servers: { "web" => { "logging" => { "driver" => [] } } }
    assert_error "servers/web/labels: should be a hash", servers: { "web" => { "labels" => [] } }
    assert_error "servers/web/env: should be a hash", servers: { "web" => { "env" => [] } }
    assert_error "servers/web/env: tags are only allowed in the root env", servers: { "web" => { "hosts" => [ "1.1.1.1" ], "env" => { "tags" => {} } } }
  end

  test "registry" do
    assert_error "registry/username: is required", registry: {}
    assert_error "registry/password: is required", registry: { "username" => "foo" }
    assert_error "registry/password: should be a string or an array with one string (for secret lookup)", registry: { "username" => "foo", "password" => [ "SECRET1", "SECRET2" ] }
    assert_error "registry/server: should be a string", registry: { "username" => "foo", "password" => "bar", "server" => [] }
  end

  test "accessories" do
    assert_error "accessories/accessory1: should be a hash", accessories: { "accessory1" => [] }
    assert_error "accessories/accessory1: unknown key: unknown", accessories: { "accessory1" => { "unknown" => "baz" } }
    assert_error "accessories/accessory1/options: should be a hash", accessories: { "accessory1" => { "options" => [] } }
    assert_error "accessories/accessory1/host: should be a string", accessories: { "accessory1" => { "host" => [] } }
    assert_error "accessories/accessory1/env: should be a hash", accessories: { "accessory1" => { "env" => [] } }
    assert_error "accessories/accessory1/env: tags are only allowed in the root env", accessories: { "accessory1" => { "host" => "host", "env" => { "tags" => {} } } }
  end

  test "env" do
    assert_error "env: should be a hash", env: []
    assert_error "env/FOO: should be a string", env: { "FOO" => [] }
    assert_error "env/clear/FOO: should be a string", env: { "clear" => { "FOO" => [] } }
    assert_error "env/secret: should be an array", env: { "secret" => { "FOO" => [] } }
    assert_error "env/secret/0: should be a string", env: { "secret" => [ [] ] }
    assert_error "env/tags: should be a hash", env: { "tags" => [] }
    assert_error "env/tags/tag1: should be a hash", env: { "tags" => { "tag1" => "foo" } }
    assert_error "env/tags/tag1/FOO: should be a string", env: { "tags" => { "tag1" => { "FOO" => [] } } }
    assert_error "env/tags/tag1/clear/FOO: should be a string", env: { "tags" => { "tag1" => { "clear" => { "FOO" => [] } } } }
    assert_error "env/tags/tag1/secret: should be an array", env: { "tags" => { "tag1" => { "secret" => {} } } }
    assert_error "env/tags/tag1/secret/0: should be a string", env: { "tags" => { "tag1" => { "secret" => [ [] ] } } }
    assert_error "env/tags/tag1: tags are only allowed in the root env", env: { "tags" => { "tag1" => { "tags" => {} } } }
  end

  test "ssh" do
    assert_error "ssh: unknown key: foo", ssh: { "foo" => "bar" }
    assert_error "ssh/user: should be a string", ssh: { "user" => [] }
  end

  test "sshkit" do
    assert_error "sshkit: unknown key: foo", sshkit: { "foo" => "bar" }
    assert_error "sshkit/max_concurrent_starts: should be an integer", sshkit: { "max_concurrent_starts" => "foo" }
  end

  test "builder" do
    assert_error "builder: unknown key: foo", builder: { "foo" => "bar" }
    assert_error "builder/remote: should be a string", builder: { "remote" => { "foo" => "bar" } }
    assert_error "builder/arch: should be an array or a string", builder: { "arch" => {} }
    assert_error "builder/args: should be a hash", builder: { "args" => [ "foo" ] }
    assert_error "builder/cache/options: should be a string", builder: { "cache" => { "options" => [] } }
  end

  private
    def assert_error(message, **invalid_config)
      valid_config = {
        service: "app",
        image: "app",
        builder: { "arch" => "amd64" },
        registry: { "username" => "user", "password" => "secret" },
        servers: [ "1.1.1.1" ]
      }

      error = assert_raises Kamal::ConfigurationError do
        Kamal::Configuration.new(valid_config.merge(invalid_config))
      end

      assert_equal message, error.message
    end
end
