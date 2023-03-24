require "test_helper"

class CommandsAccessoryTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "server" => "private.registry", "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1" ],
      accessories: {
        "mysql" => {
          "image" => "private.registry/mysql:8.0",
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
        },
        "busybox" => {
          "image" => "busybox:latest",
          "host" => "1.1.1.7"
        }
      }
    }

    @config  = Mrsk::Configuration.new(@config)
    @mysql   = Mrsk::Commands::Accessory.new(@config, name: :mysql)
    @redis   = Mrsk::Commands::Accessory.new(@config, name: :redis)
    @busybox = Mrsk::Commands::Accessory.new(@config, name: :busybox)

    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
  end

  teardown do
    ENV.delete("MYSQL_ROOT_PASSWORD")
  end

  test "run" do
    assert_equal \
      "docker run --name app-mysql --detach --restart unless-stopped --log-opt max-size=10m --publish 3306:3306 -e MYSQL_ROOT_PASSWORD=\"secret123\" -e MYSQL_ROOT_HOST=\"%\" --label service=\"app-mysql\" private.registry/mysql:8.0",
      @mysql.run.join(" ")

    assert_equal \
      "docker run --name app-redis --detach --restart unless-stopped --log-opt max-size=10m --publish 6379:6379 -e SOMETHING=\"else\" --volume /var/lib/redis:/data --label service=\"app-redis\" --label cache=\"true\" redis:latest",
      @redis.run.join(" ")

    assert_equal \
      "docker run --name app-busybox --detach --restart unless-stopped --log-opt max-size=10m --label service=\"app-busybox\" busybox:latest",
      @busybox.run.join(" ")
  end

  test "start" do
    assert_equal \
      "docker container start app-mysql",
      @mysql.start.join(" ")
  end

  test "stop" do
    assert_equal \
      "docker container stop app-mysql",
      @mysql.stop.join(" ")
  end

  test "info" do
    assert_equal \
      "docker ps --filter label=service=app-mysql",
      @mysql.info.join(" ")
  end


  test "execute in new container" do
    assert_equal \
      "docker run --rm -e MYSQL_ROOT_PASSWORD=\"secret123\" -e MYSQL_ROOT_HOST=\"%\" private.registry/mysql:8.0 mysql -u root",
      @mysql.execute_in_new_container("mysql", "-u", "root").join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-mysql mysql -u root",
      @mysql.execute_in_existing_container("mysql", "-u", "root").join(" ")
  end

  test "execute in new container over ssh" do
    @mysql.stub(:run_over_ssh, ->(cmd) { cmd.join(" ") }) do
      assert_match %r|docker run -it --rm -e MYSQL_ROOT_PASSWORD=\"secret123\" -e MYSQL_ROOT_HOST=\"%\" private.registry/mysql:8.0 mysql -u root|,
        @mysql.execute_in_new_container_over_ssh("mysql", "-u", "root")
    end
  end

  test "execute in existing container over ssh" do
    @mysql.stub(:run_over_ssh, ->(cmd) { cmd.join(" ") }) do
      assert_match %r|docker exec -it app-mysql mysql -u root|,
        @mysql.execute_in_existing_container_over_ssh("mysql", "-u", "root")
    end
  end



  test "logs" do
    assert_equal \
      "docker logs app-mysql --timestamps 2>&1",
      @mysql.logs.join(" ")

    assert_equal \
      "docker logs app-mysql  --since 5m  --tail 100 --timestamps 2>&1 | grep 'thing'",
      @mysql.logs(since: "5m", lines: 100, grep: "thing").join(" ")
  end

  test "follow logs" do
    assert_equal \
      "ssh -t root@1.1.1.5 'docker logs app-mysql --timestamps --tail 10 --follow 2>&1'",
      @mysql.follow_logs
  end

  test "remove container" do
    assert_equal \
      "docker container prune --force --filter label=service=app-mysql",
      @mysql.remove_container.join(" ")
  end

  test "remove image" do
    assert_equal \
      "docker image rm --force private.registry/mysql:8.0",
      @mysql.remove_image.join(" ")
  end
end
