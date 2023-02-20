require "test_helper"

class CommandsAppTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"

    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], env: { "secret" => [ "RAILS_MASTER_KEY" ] } }
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config).tap { |c| c.version = "999" }
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
  end

  test "run" do
    assert_equal \
      "docker run --detach --restart unless-stopped --log-opt max-size=10m --name app-999 -e RAILS_MASTER_KEY=\"456\" --label service=\"app\" --label role=\"web\" --label traefik.http.routers.app.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.services.app.loadbalancer.healthcheck.path=\"/up\" --label traefik.http.services.app.loadbalancer.healthcheck.interval=\"1s\" --label traefik.http.middlewares.app.retry.attempts=\"3\" --label traefik.http.middlewares.app.retry.initialinterval=\"500ms\" dhh/app:999",
      @app.run.join(" ")
  end

  test "run with volumes" do
    @config[:volumes] = ["/local/path:/container/path" ]

    assert_equal \
      "docker run --detach --restart unless-stopped --log-opt max-size=10m --name app-999 -e RAILS_MASTER_KEY=\"456\" --volume /local/path:/container/path --label service=\"app\" --label role=\"web\" --label traefik.http.routers.app.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.services.app.loadbalancer.healthcheck.path=\"/up\" --label traefik.http.services.app.loadbalancer.healthcheck.interval=\"1s\" --label traefik.http.middlewares.app.retry.attempts=\"3\" --label traefik.http.middlewares.app.retry.initialinterval=\"500ms\" dhh/app:999",
      @app.run.join(" ")
  end

  test "run with custom healthcheck path" do
    @config[:healthcheck] = { "path" => "/healthz" }

    assert_equal \
      "docker run --detach --restart unless-stopped --log-opt max-size=10m --name app-999 -e RAILS_MASTER_KEY=\"456\" --label service=\"app\" --label role=\"web\" --label traefik.http.routers.app.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.services.app.loadbalancer.healthcheck.path=\"/healthz\" --label traefik.http.services.app.loadbalancer.healthcheck.interval=\"1s\" --label traefik.http.middlewares.app.retry.attempts=\"3\" --label traefik.http.middlewares.app.retry.initialinterval=\"500ms\" dhh/app:999",
      @app.run.join(" ")
  end

  test "start" do
    assert_equal \
      "docker start app-999",
      @app.start.join(" ")
  end

  test "stop" do
    assert_equal \
      "docker ps --quiet --filter label=service=app | xargs docker stop",
      @app.stop.join(" ")
  end

  test "info" do
    assert_equal \
      "docker ps --filter label=service=app",
      @app.info.join(" ")
  end


  test "logs" do
    assert_equal \
      "docker ps --quiet --filter label=service=app | xargs docker logs 2>&1",
      @app.logs.join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app | xargs docker logs --since 5m 2>&1",
      @app.logs(since: "5m").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app | xargs docker logs --tail 100 2>&1",
      @app.logs(lines: "100").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app | xargs docker logs --since 5m --tail 100 2>&1",
      @app.logs(since: "5m", lines: "100").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app | xargs docker logs 2>&1 | grep 'my-id'",
      @app.logs(grep: "my-id").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app | xargs docker logs --since 5m 2>&1 | grep 'my-id'",
      @app.logs(since: "5m", grep: "my-id").join(" ")
  end

  test "follow logs" do
    @app.stub(:run_over_ssh, ->(cmd, host:) { cmd.join(" ") }) do
      assert_equal \
        "docker ps --quiet --filter label=service=app | xargs docker logs --timestamps --tail 10 --follow 2>&1",
        @app.follow_logs(host: "app-1")

      assert_equal \
        "docker ps --quiet --filter label=service=app | xargs docker logs --timestamps --tail 10 --follow 2>&1 | grep \"Completed\"",
        @app.follow_logs(host: "app-1", grep: "Completed")
    end
  end


  test "execute in new container" do
    assert_equal \
      "docker run --rm -e RAILS_MASTER_KEY=\"456\" dhh/app:999 bin/rails db:setup",
      @app.execute_in_new_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-999 bin/rails db:setup",
      @app.execute_in_existing_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in new container over ssh" do
    @app.stub(:run_over_ssh, ->(cmd, host:) { cmd.join(" ") }) do
      assert_match %r|docker run -it --rm -e RAILS_MASTER_KEY=\"456\" dhh/app:999 bin/rails c|,
        @app.execute_in_new_container_over_ssh("bin/rails", "c", host: "app-1")
    end
  end

  test "execute in existing container over ssh" do
    @app.stub(:run_over_ssh, ->(cmd, host:) { cmd.join(" ") }) do
      assert_match %r|docker exec -it app-999 bin/rails c|,
        @app.execute_in_existing_container_over_ssh("bin/rails", "c", host: "app-1")
    end
  end

  test "run over ssh" do
    assert_equal "ssh -t root@1.1.1.1 'ls'", @app.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with custom user" do
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config.tap { |c| c[:ssh] = { "user" => "app" } })
    assert_equal "ssh -t app@1.1.1.1 'ls'", @app.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with proxy" do
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config.tap { |c| c[:ssh] = { "proxy" => "2.2.2.2" } })
    assert_equal "ssh -J root@2.2.2.2 -t root@1.1.1.1 'ls'", @app.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with proxy user" do
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config.tap { |c| c[:ssh] = { "proxy" => "app@2.2.2.2" } })
    assert_equal "ssh -J app@2.2.2.2 -t root@1.1.1.1 'ls'", @app.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with custom user with proxy" do
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config.tap { |c| c[:ssh] = { "user" => "app", "proxy" => "2.2.2.2" } })
    assert_equal "ssh -J root@2.2.2.2 -t app@1.1.1.1 'ls'", @app.run_over_ssh("ls", host: "1.1.1.1")
  end


  test "current_container_id" do
    assert_equal \
      "docker ps --quiet --filter label=service=app",
      @app.current_container_id.join(" ")
  end

  test "container_id_for" do
    assert_equal \
      "docker container ls --all --filter name=app-999 --quiet",
      @app.container_id_for(container_name: "app-999").join(" ")
  end

  test "current_running_version" do
    assert_equal \
      "docker ps --filter label=service=app --format \"{{.Names}}\" | sed 's/-/\\n/g' | tail -n 1",
      @app.current_running_version.join(" ")
  end

  test "most_recent_version_from_available_images" do
    assert_equal \
      "docker image ls --format \"{{.Tag}}\" dhh/app | head -n 1",
      @app.most_recent_version_from_available_images.join(" ")
  end
end
