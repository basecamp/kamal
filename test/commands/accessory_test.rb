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
            "cache" => "true"
          },
          "env" => {
            "SOMETHING" => "else"
          },
          "volumes" => [
            "/var/lib/redis:/data"
          ]
        },
        "busybox" => {
          "service" => "custom-busybox",
          "image" => "busybox:latest",
          "host" => "1.1.1.7"
        }
      }
    }

    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
  end

  teardown do
    ENV.delete("MYSQL_ROOT_PASSWORD")
  end

  test "run" do
    assert_equal \
      "docker run --name app-mysql --detach --restart unless-stopped --log-opt max-size=\"10m\" --publish 3306:3306 --env-file .kamal/env/accessories/app-mysql.env --env MYSQL_ROOT_HOST=\"%\" --label service=\"app-mysql\" private.registry/mysql:8.0",
      new_command(:mysql).run.join(" ")

    assert_equal \
      "docker run --name app-redis --detach --restart unless-stopped --log-opt max-size=\"10m\" --publish 6379:6379 --env-file .kamal/env/accessories/app-redis.env --env SOMETHING=\"else\" --volume /var/lib/redis:/data --label service=\"app-redis\" --label cache=\"true\" redis:latest",
      new_command(:redis).run.join(" ")

    assert_equal \
      "docker run --name custom-busybox --detach --restart unless-stopped --log-opt max-size=\"10m\" --env-file .kamal/env/accessories/custom-busybox.env --label service=\"custom-busybox\" busybox:latest",
      new_command(:busybox).run.join(" ")
  end

  test "run with logging config" do
    @config[:logging] = { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => "3" } }

    assert_equal \
      "docker run --name custom-busybox --detach --restart unless-stopped --log-driver \"local\" --log-opt max-size=\"100m\" --log-opt max-file=\"3\" --env-file .kamal/env/accessories/custom-busybox.env --label service=\"custom-busybox\" busybox:latest",
      new_command(:busybox).run.join(" ")
  end

  test "start" do
    assert_equal \
      "docker container start app-mysql",
      new_command(:mysql).start.join(" ")
  end

  test "stop" do
    assert_equal \
      "docker container stop app-mysql",
      new_command(:mysql).stop.join(" ")
  end

  test "info" do
    assert_equal \
      "docker ps --filter label=service=app-mysql",
      new_command(:mysql).info.join(" ")
  end


  test "execute in new container" do
    assert_equal \
      "docker run --rm --env-file .kamal/env/accessories/app-mysql.env --env MYSQL_ROOT_HOST=\"%\" private.registry/mysql:8.0 mysql -u root",
      new_command(:mysql).execute_in_new_container("mysql", "-u", "root").join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-mysql mysql -u root",
      new_command(:mysql).execute_in_existing_container("mysql", "-u", "root").join(" ")
  end

  test "execute in new container over ssh" do
    new_command(:mysql).stub(:run_over_ssh, ->(cmd) { cmd.join(" ") }) do
      assert_match %r{docker run -it --rm --env-file .kamal/env/accessories/app-mysql.env --env MYSQL_ROOT_HOST=\"%\" private.registry/mysql:8.0 mysql -u root},
        new_command(:mysql).execute_in_new_container_over_ssh("mysql", "-u", "root")
    end
  end

  test "execute in existing container over ssh" do
    new_command(:mysql).stub(:run_over_ssh, ->(cmd) { cmd.join(" ") }) do
      assert_match %r{docker exec -it app-mysql mysql -u root},
        new_command(:mysql).execute_in_existing_container_over_ssh("mysql", "-u", "root")
    end
  end



  test "logs" do
    assert_equal \
      "docker logs app-mysql --timestamps 2>&1",
      new_command(:mysql).logs.join(" ")

    assert_equal \
      "docker logs app-mysql  --since 5m  --tail 100 --timestamps 2>&1 | grep 'thing'",
      new_command(:mysql).logs(since: "5m", lines: 100, grep: "thing").join(" ")

    assert_equal \
      "docker logs app-mysql  --since 5m  --tail 100 --timestamps 2>&1 | grep 'thing' -C 2",
      new_command(:mysql).logs(since: "5m", lines: 100, grep: "thing", grep_options: "-C 2").join(" ")
  end

  test "follow logs" do
    assert_equal \
      "ssh -t root@1.1.1.5 -p 22 'docker logs app-mysql --timestamps --tail 10 --follow 2>&1'",
      new_command(:mysql).follow_logs
  end

  test "remove container" do
    assert_equal \
      "docker container prune --force --filter label=service=app-mysql",
      new_command(:mysql).remove_container.join(" ")
  end

  test "remove image" do
    assert_equal \
      "docker image rm --force private.registry/mysql:8.0",
      new_command(:mysql).remove_image.join(" ")
  end

  test "make_env_directory" do
    assert_equal "mkdir -p .kamal/env/accessories", new_command(:mysql).make_env_directory.join(" ")
  end

  test "remove_env_file" do
    assert_equal "rm -f .kamal/env/accessories/app-mysql.env", new_command(:mysql).remove_env_file.join(" ")
  end

  private
    def new_command(accessory)
      Kamal::Commands::Accessory.new(Kamal::Configuration.new(@config), name: accessory)
    end
end
