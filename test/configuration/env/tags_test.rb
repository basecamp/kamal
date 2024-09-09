require "test_helper"

class ConfigurationEnvTagsTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ { "1.1.1.1" => "odd" }, { "1.1.1.2" => "even" }, { "1.1.1.3" => [ "odd", "three" ] } ],
      builder: { "arch" => "amd64" },
      env: {
        "clear" => { "REDIS_URL" => "redis://x/y", "THREE" => "false" },
        "tags" => {
          "odd" => { "TYPE" => "odd" },
          "even" => { "TYPE" => "even" },
          "three" => { "THREE" => "true" }
        }
      }
    }

    @config = Kamal::Configuration.new(@deploy)

    @deploy_with_roles = @deploy.dup.merge({
      servers: {
        "web" => [ { "1.1.1.1" => "odd" }, "1.1.1.2" ],
        "workers" => {
          "hosts" => [ { "1.1.1.3" => [ "odd", "oddjob" ] }, "1.1.1.4" ],
          "cmd" => "bin/jobs",
          "env" => {
            "REDIS_URL" => "redis://a/b",
            "WEB_CONCURRENCY" => 4
          }
        }
      },
      env: {
        "tags" => {
          "odd" => { "TYPE" => "odd" },
          "oddjob" => { "TYPE" => "oddjob" }
        }
      }
    })

    @config_with_roles = Kamal::Configuration.new(@deploy_with_roles)
  end

  test "tags" do
    assert_equal 3, @config.env_tags.size
    assert_equal %w[ odd even three ], @config.env_tags.map(&:name)
    assert_equal({ "TYPE" => "odd" }, @config.env_tag("odd").env.clear)
    assert_equal({ "TYPE" => "even" }, @config.env_tag("even").env.clear)
    assert_equal({ "THREE" => "true" }, @config.env_tag("three").env.clear)
  end

  test "tags with roles" do
    assert_equal 2, @config_with_roles.env_tags.size
    assert_equal %w[ odd oddjob ], @config_with_roles.env_tags.map(&:name)
    assert_equal({ "TYPE" => "odd" }, @config_with_roles.env_tag("odd").env.clear)
    assert_equal({ "TYPE" => "oddjob" }, @config_with_roles.env_tag("oddjob").env.clear)
  end

  test "tag overrides env" do
    assert_equal "false", @config.role("web").env("1.1.1.1").clear["THREE"]
    assert_equal "true", @config.role("web").env("1.1.1.3").clear["THREE"]
  end

  test "later tag wins" do
    deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ { "1.1.1.1" => [ "first", "second" ] } ],
      builder: { "arch" => "amd64" },
      env: {
        "tags" => {
          "first" => { "TYPE" => "first" },
          "second" => { "TYPE" => "second" }
        }
      }
    }

    config = Kamal::Configuration.new(deploy)
    assert_equal "second", config.role("web").env("1.1.1.1").clear["TYPE"]
  end

  test "tag secret env" do
    with_test_secrets("secrets" => "PASSWORD=hello") do
      deploy = {
        service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
        servers: [ { "1.1.1.1" => "secrets" } ],
        builder: { "arch" => "amd64" },
        env: {
          "tags" => {
            "secrets" => { "secret" => [ "PASSWORD" ] }
          }
        }
      }

      config = Kamal::Configuration.new(deploy)
      assert_equal "hello", config.role("web").env("1.1.1.1").secrets["PASSWORD"]
    end
  end

  test "tag clear env" do
    deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ { "1.1.1.1" => "clearly" } ],
      builder: { "arch" => "amd64" },
      env: {
        "tags" => {
          "clearly" => { "clear" => { "FOO" => "bar" } }
        }
      }
    }

    config = Kamal::Configuration.new(deploy)
    assert_equal "bar", config.role("web").env("1.1.1.1").clear["FOO"]
  end
end
