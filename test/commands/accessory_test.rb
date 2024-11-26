require "test_helper"

class CommandsAccessoryTest < ActiveSupport::TestCase
  setup do
    setup_test_secrets("secrets" => "MYSQL_ROOT_PASSWORD=secret123")

    @config = {
      service: "app", image: "dhh/app", registry: { "server" => "private.registry", "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1" ],
      builder: { "arch" => "amd64" },
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
          "host" => "1.1.1.7",
          "proxy" => {
            "host" => "busybox.example.com"
          }
        }
      }
    }
  end

  teardown do
    teardown_test_secrets
  end

  test "run" do
    assert_equal \
      "docker run --name app-mysql --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 3306:3306 --env MYSQL_ROOT_HOST=\"%\" --env-file .kamal/apps/app/env/accessories/mysql.env --label service=\"app-mysql\" private.registry/mysql:8.0",
      new_command(:mysql).run.join(" ")

    assert_equal \
      "docker run --name app-redis --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 6379:6379 --env SOMETHING=\"else\" --env-file .kamal/apps/app/env/accessories/redis.env --volume /var/lib/redis:/data --label service=\"app-redis\" --label cache=\"true\" redis:latest",
      new_command(:redis).run.join(" ")

    assert_equal \
      "docker run --name custom-busybox --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --env-file .kamal/apps/app/env/accessories/busybox.env --label service=\"custom-busybox\" busybox:latest",
      new_command(:busybox).run.join(" ")
  end

  test "run with logging config" do
    @config[:logging] = { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => "3" } }

    assert_equal \
      "docker run --name custom-busybox --detach --restart unless-stopped --network kamal --log-driver \"local\" --log-opt max-size=\"100m\" --log-opt max-file=\"3\" --env-file .kamal/apps/app/env/accessories/busybox.env --label service=\"custom-busybox\" busybox:latest",
      new_command(:busybox).run.join(" ")
  end

  test "run in custom network" do
    @config[:accessories]["mysql"]["network"] = "custom"

    assert_equal \
      "docker run --name app-mysql --detach --restart unless-stopped --network custom --log-opt max-size=\"10m\" --publish 3306:3306 --env MYSQL_ROOT_HOST=\"%\" --env-file .kamal/apps/app/env/accessories/mysql.env --label service=\"app-mysql\" private.registry/mysql:8.0",
      new_command(:mysql).run.join(" ")
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
      "docker run --rm --network kamal --env MYSQL_ROOT_HOST=\"%\" --env-file .kamal/apps/app/env/accessories/mysql.env private.registry/mysql:8.0 mysql -u root",
      new_command(:mysql).execute_in_new_container("mysql", "-u", "root").join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-mysql mysql -u root",
      new_command(:mysql).execute_in_existing_container("mysql", "-u", "root").join(" ")
  end

  test "execute in new container over ssh" do
    new_command(:mysql).stub(:run_over_ssh, ->(cmd) { cmd.join(" ") }) do
      assert_match %r{docker run -it --rm --network kamal --env MYSQL_ROOT_HOST=\"%\" --env-file .kamal/apps/app/env/accessories/mysql.env private.registry/mysql:8.0 mysql -u root},
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

    assert_equal \
      "docker logs app-mysql  --since 5m  --tail 100 2>&1 | grep 'thing' -C 2",
      new_command(:mysql).logs(timestamps: false, since: "5m", lines: 100, grep: "thing", grep_options: "-C 2").join(" ")
  end

  test "follow logs" do
    assert_equal \
      "ssh -t root@1.1.1.5 -p 22 'docker logs app-mysql --timestamps --tail 10 --follow 2>&1'",
      new_command(:mysql).follow_logs

    assert_equal \
      "ssh -t root@1.1.1.5 -p 22 'docker logs app-mysql --tail 10 --follow 2>&1'",
      new_command(:mysql).follow_logs(timestamps: false)
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

  test "deploy" do
    assert_equal \
      "docker exec kamal-proxy kamal-proxy deploy custom-busybox --target=\"172.1.0.2:80\" --host=\"busybox.example.com\" --deploy-timeout=\"30s\" --drain-timeout=\"30s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"",
      new_command(:busybox).deploy(target: "172.1.0.2").join(" ")
  end

  test "remove" do
    assert_equal \
      "docker exec kamal-proxy kamal-proxy remove custom-busybox",
      new_command(:busybox).remove.join(" ")
  end

  private
    def new_command(accessory)
      Kamal::Commands::Accessory.new(Kamal::Configuration.new(@config), name: accessory)
    end
end
