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
      "docker run --detach --restart unless-stopped --name app-web-999 -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with hostname" do
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --hostname myhost -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run(hostname: "myhost").join(" ")
  end

  test "run with volumes" do
    @config[:volumes] = ["/local/path:/container/path" ]

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" --log-opt max-size=\"10m\" --volume /local/path:/container/path --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom healthcheck path" do
    @config[:healthcheck] = { "path" => "/healthz" }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"curl -f http://localhost:3000/healthz || exit 1\" --health-interval \"1s\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom healthcheck command" do
    @config[:healthcheck] = { "cmd" => "/bin/up" }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"/bin/up\" --health-interval \"1s\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with role-specific healthcheck options" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "healthcheck" => { "cmd" => "/bin/healthy" } } }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"/bin/healthy\" --health-interval \"1s\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom options" do
    @config[:servers] = { "web" => [ "1.1.1.1" ], "jobs" => { "hosts" => [ "1.1.1.2" ], "cmd" => "bin/jobs", "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-jobs-999 -e MRSK_CONTAINER_NAME=\"app-jobs-999\" -e RAILS_MASTER_KEY=\"456\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"jobs\" --mount \"somewhere\" --cap-add dhh/app:999 bin/jobs",
      new_command(role: "jobs").run.join(" ")
  end

  test "run with logging config" do
    @config[:logging] = { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => "3" } }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" --log-driver \"local\" --log-opt max-size=\"100m\" --log-opt max-file=\"3\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "start" do
    assert_equal \
      "docker start app-web-999",
      new_command.start.join(" ")
  end

  test "start with destination" do
    @destination = "staging"
    assert_equal \
      "docker start app-web-staging-999",
      new_command.start.join(" ")
  end

  test "start_or_run" do
    assert_equal \
      "docker start app-web-999 || docker run --detach --restart unless-stopped --name app-web-999 -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.start_or_run.join(" ")
  end

  test "start_or_run with hostname" do
    assert_equal \
      "docker start app-web-999 || docker run --detach --restart unless-stopped --name app-web-999 --hostname myhost -e MRSK_CONTAINER_NAME=\"app-web-999\" -e RAILS_MASTER_KEY=\"456\" --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.start_or_run(hostname: "myhost").join(" ")
  end

  test "stop" do
    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker stop",
      new_command.stop.join(" ")
  end

  test "stop with custom stop wait time" do
    @config[:stop_wait_time] = 30
    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker stop -t 30",
      new_command.stop.join(" ")
  end

  test "stop with version" do
    assert_equal \
      "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop",
      new_command.stop(version: "123").join(" ")
  end

  test "info" do
    assert_equal \
      "docker ps --filter label=service=app --filter label=role=web",
      new_command.info.join(" ")
  end

  test "info with destination" do
    @destination = "staging"
    assert_equal \
      "docker ps --filter label=service=app --filter label=destination=staging --filter label=role=web",
      new_command.info.join(" ")
  end


  test "logs" do
    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs 2>&1",
      new_command.logs.join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --since 5m 2>&1",
      new_command.logs(since: "5m").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --tail 100 2>&1",
      new_command.logs(lines: "100").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --since 5m --tail 100 2>&1",
      new_command.logs(since: "5m", lines: "100").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs 2>&1 | grep 'my-id'",
      new_command.logs(grep: "my-id").join(" ")

    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --since 5m 2>&1 | grep 'my-id'",
      new_command.logs(since: "5m", grep: "my-id").join(" ")
  end

  test "follow logs" do
    assert_match \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --timestamps --tail 10 --follow 2>&1",
      new_command.follow_logs(host: "app-1")

    assert_match \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --timestamps --tail 10 --follow 2>&1 | grep \"Completed\"",
      new_command.follow_logs(host: "app-1", grep: "Completed")
  end


  test "execute in new container" do
    assert_equal \
      "docker run --rm -e RAILS_MASTER_KEY=\"456\" dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in new container with custom options" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_equal \
      "docker run --rm -e RAILS_MASTER_KEY=\"456\" --mount \"somewhere\" --cap-add dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-web-999 bin/rails db:setup",
      new_command.execute_in_existing_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in new container over ssh" do
    assert_match %r|docker run -it --rm -e RAILS_MASTER_KEY=\"456\" dhh/app:999 bin/rails c|,
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", host: "app-1")
  end

  test "execute in new container with custom options over ssh" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_match %r|docker run -it --rm -e RAILS_MASTER_KEY=\"456\" --mount \"somewhere\" --cap-add dhh/app:999 bin/rails c|,
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", host: "app-1")
  end

  test "execute in existing container over ssh" do
    assert_match %r|docker exec -it app-web-999 bin/rails c|,
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

  test "run over ssh with proxy_command" do
    @config[:ssh] = { "proxy_command" => "ssh -W %h:%p user@proxy-server" }
    assert_equal "ssh -o ProxyCommand='ssh -W %h:%p user@proxy-server' -t root@1.1.1.1 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "current_running_container_id" do
    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest",
      new_command.current_running_container_id.join(" ")
  end

  test "current_running_container_id with destination" do
    @destination = "staging"
    assert_equal \
      "docker ps --quiet --filter label=service=app --filter label=destination=staging --filter label=role=web --filter status=running --filter status=restarting --latest",
      new_command.current_running_container_id.join(" ")
  end

  test "container_id_for" do
    assert_equal \
      "docker container ls --all --filter name=^app-999$ --quiet",
      new_command.container_id_for(container_name: "app-999").join(" ")
  end

  test "current_running_version" do
    assert_equal \
      "docker ps --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest --format \"{{.Names}}\" | grep -oE \"\\-[^-]+$\" | cut -c 2-",
      new_command.current_running_version.join(" ")
  end

  test "list_versions" do
    assert_equal \
      "docker ps --filter label=service=app --filter label=role=web --format \"{{.Names}}\" | grep -oE \"\\-[^-]+$\" | cut -c 2-",
      new_command.list_versions.join(" ")

    assert_equal \
      "docker ps --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest --format \"{{.Names}}\" | grep -oE \"\\-[^-]+$\" | cut -c 2-",
      new_command.list_versions("--latest", statuses: [ :running, :restarting ]).join(" ")
  end

  test "list_containers" do
    assert_equal \
      "docker container ls --all --filter label=service=app --filter label=role=web",
      new_command.list_containers.join(" ")
  end

  test "list_containers with destination" do
    @destination = "staging"
    assert_equal \
      "docker container ls --all --filter label=service=app --filter label=destination=staging --filter label=role=web",
      new_command.list_containers.join(" ")
  end

  test "list_container_names" do
    assert_equal \
      "docker container ls --all --filter label=service=app --filter label=role=web --format '{{ .Names }}'",
      new_command.list_container_names.join(" ")
  end

  test "remove_container" do
    assert_equal \
      "docker container ls --all --filter name=^app-web-999$ --quiet | xargs docker container rm",
      new_command.remove_container(version: "999").join(" ")
  end

  test "remove_container with destination" do
    @destination = "staging"
    assert_equal \
      "docker container ls --all --filter name=^app-web-staging-999$ --quiet | xargs docker container rm",
      new_command.remove_container(version: "999").join(" ")
  end

  test "remove_containers" do
    assert_equal \
      "docker container prune --force --filter label=service=app --filter label=role=web",
      new_command.remove_containers.join(" ")
  end

  test "remove_containers with destination" do
    @destination = "staging"
    assert_equal \
      "docker container prune --force --filter label=service=app --filter label=destination=staging --filter label=role=web",
      new_command.remove_containers.join(" ")
  end

  test "list_images" do
    assert_equal \
      "docker image ls dhh/app",
      new_command.list_images.join(" ")
  end

  test "remove_images" do
    assert_equal \
      "docker image prune --all --force --filter label=service=app --filter label=role=web",
      new_command.remove_images.join(" ")
  end

  test "remove_images with destination" do
    @destination = "staging"
    assert_equal \
      "docker image prune --all --force --filter label=service=app --filter label=destination=staging --filter label=role=web",
      new_command.remove_images.join(" ")
  end

  test "tag_current_as_latest" do
    assert_equal \
      "docker tag dhh/app:999 dhh/app:latest",
      new_command.tag_current_as_latest.join(" ")
  end

  private
    def new_command(role: "web")
      Mrsk::Commands::App.new(Mrsk::Configuration.new(@config, destination: @destination, version: "999"), role: role)
    end
end
