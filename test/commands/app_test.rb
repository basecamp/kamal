require "test_helper"

class CommandsAppTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"

    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], env: { "secret" => [ "RAILS_MASTER_KEY" ] } }
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
  end

  test "run" do
    assert_equal \
      "docker run --detach --restart unless-stopped --log-opt max-size=10m --name app-999 -e MRSK_CONTAINER_NAME=\"app-999\" -e RAILS_MASTER_KEY=\"456\" --label service=\"app\" --label role=\"web\" --label traefik.http.routers.app.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.services.app.loadbalancer.healthcheck.path=\"/up\" --label traefik.http.services.app.loadbalancer.healthcheck.interval=\"1s\" --label traefik.http.middlewares.app-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app.middlewares=\"app-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with volumes" do
    @config[:volumes] = ["/local/path:/container/path" ]

    assert_equal \
      "docker run --detach --restart unless-stopped --log-opt max-size=10m --name app-999 -e MRSK_CONTAINER_NAME=\"app-999\" -e RAILS_MASTER_KEY=\"456\" --volume /local/path:/container/path --label service=\"app\" --label role=\"web\" --label traefik.http.routers.app.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.services.app.loadbalancer.healthcheck.path=\"/up\" --label traefik.http.services.app.loadbalancer.healthcheck.interval=\"1s\" --label traefik.http.middlewares.app-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app.middlewares=\"app-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom healthcheck path" do
    @config[:healthcheck] = { "path" => "/healthz" }

    assert_equal \
      "docker run --detach --restart unless-stopped --log-opt max-size=10m --name app-999 -e MRSK_CONTAINER_NAME=\"app-999\" -e RAILS_MASTER_KEY=\"456\" --label service=\"app\" --label role=\"web\" --label traefik.http.routers.app.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.services.app.loadbalancer.healthcheck.path=\"/healthz\" --label traefik.http.services.app.loadbalancer.healthcheck.interval=\"1s\" --label traefik.http.middlewares.app-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app.middlewares=\"app-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom options" do
    @config[:servers] = { "web" => [ "1.1.1.1" ], "jobs" => { "hosts" => [ "1.1.1.2" ], "cmd" => "bin/jobs", "options" => { "mount" => "somewhere", "cap-add" => true } } }

    assert_equal \
      "docker run --detach --restart unless-stopped --log-opt max-size=10m --name app-999 -e MRSK_CONTAINER_NAME=\"app-999\" -e RAILS_MASTER_KEY=\"456\" --label service=\"app\" --label role=\"jobs\" --mount \"somewhere\" --cap-add dhh/app:999 bin/jobs",
      new_command.run(role: :jobs).join(" ")
  end

  test "start" do
    assert_equal \
      "docker start app-999",
      new_command.start.join(" ")
  end

  test "start with destination" do
    @destination = "staging"
    assert_equal \
      "docker start app-staging-999",
      new_command.start.join(" ")
  end

  test "stop" do
    assert_equal \
      "docker ps --quiet --filter label=service=app --latest | xargs docker stop -t 10",
      new_command.stop.join(" ")
  end

  test "stop with version" do
    assert_equal \
      "docker container ls --all --filter name=app-123 --quiet | xargs docker stop -t 10",
      new_command.stop(version: "123").join(" ")
  end

  test "info" do
    assert_equal \
      "docker ps --filter label=service=app --latest",
      new_command.info.join(" ")
  end

  test "info with destination" do
    @destination = "staging"
    assert_equal \
      "docker ps --filter label=service=app --filter label=destination=staging --latest",
      new_command.info.join(" ")
  end


  test "logs" do
    assert_equal \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs 2>&1",
      new_command.logs.join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs --since 5m 2>&1",
      new_command.logs(since: "5m").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs --tail 100 2>&1",
      new_command.logs(lines: "100").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs --since 5m --tail 100 2>&1",
      new_command.logs(since: "5m", lines: "100").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs 2>&1 | grep 'my-id'",
      new_command.logs(grep: "my-id").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs --since 5m 2>&1 | grep 'my-id'",
      new_command.logs(since: "5m", grep: "my-id").join(" ")
  end

  test "follow logs" do
    assert_match \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs --timestamps --tail 10 --follow 2>&1",
      new_command.follow_logs(host: "app-1")

    assert_match \
      "docker ps --quiet --filter label=service=app --latest | xargs docker logs --timestamps --tail 10 --follow 2>&1 | grep \"Completed\"",
      new_command.follow_logs(host: "app-1", grep: "Completed")
  end


  test "execute in new container" do
    assert_equal \
      "docker run --rm -e RAILS_MASTER_KEY=\"456\" dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-999 bin/rails db:setup",
      new_command.execute_in_existing_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in new container over ssh" do
    assert_match %r|docker run -it --rm -e RAILS_MASTER_KEY=\"456\" dhh/app:999 bin/rails c|,
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", host: "app-1")
  end

  test "execute in existing container over ssh" do
    assert_match %r|docker exec -it app-999 bin/rails c|,
      new_command.execute_in_existing_container_over_ssh("bin/rails", "c", host: "app-1")
  end

  test "run over ssh" do
    assert_equal "ssh -t root@1.1.1.1 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with custom user" do
    @config[:ssh] = { "user" => "app" }
    assert_equal "ssh -t app@1.1.1.1 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with proxy" do
    @config[:ssh] = { "proxy" => "2.2.2.2" }
    assert_equal "ssh -J root@2.2.2.2 -t root@1.1.1.1 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with proxy user" do
    @config[:ssh] = { "proxy" => "app@2.2.2.2" }
    assert_equal "ssh -J app@2.2.2.2 -t root@1.1.1.1 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with custom user with proxy" do
    @config[:ssh] = { "user" => "app", "proxy" => "2.2.2.2" }
    assert_equal "ssh -J root@2.2.2.2 -t app@1.1.1.1 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end


  test "current_container_id" do
    assert_equal \
      "docker ps --quiet --filter label=service=app --latest",
      new_command.current_container_id.join(" ")
  end

  test "current_container_id with destination" do
    @destination = "staging"
    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=destination=staging --latest",
      new_command.current_container_id.join(" ")
  end

  test "container_id_for" do
    assert_equal \
      "docker container ls --all --filter name=app-999 --quiet",
      new_command.container_id_for(container_name: "app-999").join(" ")
  end

  test "current_running_version" do
    assert_equal \
      "docker ps --filter label=service=app --format \"{{.Names}}\" --latest | sed 's/-/\\n/g' | tail -n 1",
      new_command.current_running_version.join(" ")
  end

  test "most_recent_version_from_available_images" do
    assert_equal \
      "docker image ls --format \"{{.Tag}}\" dhh/app | head -n 1",
      new_command.most_recent_version_from_available_images.join(" ")
  end

  test "list_containers" do
    assert_equal \
      "docker container ls --all --filter label=service=app",
      new_command.list_containers.join(" ")
  end

  test "list_containers with destination" do
    @destination = "staging"
    assert_equal \
      "docker container ls --all --filter label=service=app --filter label=destination=staging",
      new_command.list_containers.join(" ")
  end

  test "list_container_names" do
    assert_equal \
      "docker container ls --all --filter label=service=app --format '{{ .Names }}'",
      new_command.list_container_names.join(" ")
  end

  test "remove_container" do
    assert_equal \
      "docker container ls --all --filter name=app-999 --quiet | xargs docker container rm",
      new_command.remove_container(version: "999").join(" ")
  end

  test "remove_container with destination" do
    @destination = "staging"
    assert_equal \
      "docker container ls --all --filter name=app-staging-999 --quiet | xargs docker container rm",
      new_command.remove_container(version: "999").join(" ")
  end

  test "remove_containers" do
    assert_equal \
      "docker container prune --force --filter label=service=app",
      new_command.remove_containers.join(" ")
  end

  test "remove_containers with destination" do
    @destination = "staging"
    assert_equal \
      "docker container prune --force --filter label=service=app --filter label=destination=staging",
      new_command.remove_containers.join(" ")
  end

  test "list_images" do
    assert_equal \
      "docker image ls dhh/app",
      new_command.list_images.join(" ")
  end

  test "remove_images" do
    assert_equal \
      "docker image prune --all --force --filter label=service=app",
      new_command.remove_images.join(" ")
  end

  test "remove_images with destination" do
    @destination = "staging"
    assert_equal \
      "docker image prune --all --force --filter label=service=app --filter label=destination=staging",
      new_command.remove_images.join(" ")
  end

  private
    def new_command
      Mrsk::Commands::App.new(Mrsk::Configuration.new(@config, destination: @destination, version: "999"))
    end
end
