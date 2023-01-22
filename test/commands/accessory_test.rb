require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/accessory"

class CommandsAccessoryTest < ActiveSupport::TestCase
  setup do
    @config = { 
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1" ],
      accessories: {
        "mysql" => {
          "image" => "mysql:8.0",
          "host" => "1.1.1.5",
          "port" => "3306",
          "env" => {
            "clear" => {
              "MYSQL_ROOT_HOST" => "%"
            },
            "secret" => [
              "MYSQL_ROOT_PASSWORD"
            ]
          }
        },
        "redis" => {
          "image" => "redis:latest",
          "host" => "1.1.1.6",
          "port" => "6379:6379",
          "labels" => {
            "cache" => true
          },
          "env" => {
            "SOMETHING" => "else"
          },
          "volumes" => [
            "/var/lib/redis:/data"
          ]
        }
      }
    }

    @config = Mrsk::Configuration.new(@config)
    @mysql  = Mrsk::Commands::Accessory.new(@config, name: :mysql)
    @redis  = Mrsk::Commands::Accessory.new(@config, name: :redis)
  end

  test "run" do
    assert_equal \
      [:docker, :run, "--name", "app-mysql", "-d", "--restart", "unless-stopped", "-p", "3306:3306", "--label", "service=app-mysql", "mysql:8.0"], @mysql.run

    assert_equal \
      [:docker, :run, "--name", "app-redis", "-d", "--restart", "unless-stopped", "-p", "6379:6379", "--volume", "/var/lib/redis:/data", "--label", "service=app-redis", "--label", "cache=true", "redis:latest"], @redis.run
  end

  test "start" do
    assert_equal [:docker, :container, :start, "app-mysql"], @mysql.start
  end

  test "stop" do
    assert_equal [:docker, :container, :stop, "app-mysql"], @mysql.stop
  end

  test "info" do
    assert_equal [:docker, :ps, "--filter", "name=app-mysql"], @mysql.info
  end

  test "logs" do
    assert_equal [:docker, :logs, "app-mysql", "-t", "2>&1"], @mysql.logs
    assert_equal [:docker, :logs, "app-mysql", " --since 5m", " -n 100", "-t", "2>&1", "|", "grep 'thing'"], @mysql.logs(since: "5m", lines: 100, grep: "thing")
  end

  test "follow logs" do
    assert_equal "ssh -t root@1.1.1.5 'docker logs app-mysql -t -n 10 -f 2>&1'", @mysql.follow_logs
  end

  test "remove container" do
    assert_equal [:docker, :container, :prune, "-f", "--filter", "label=name=app-mysql"], @mysql.remove_container
  end

  test "remove image" do
    assert_equal [:docker, :image, :prune, "-a", "-f", "--filter", "label=name=app-mysql"], @mysql.remove_image
  end
end
