require "test_helper"

class CommandsAppTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"
    Kamal::Configuration.any_instance.stubs(:run_id).returns("12345678901234567890123456789012")

    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], env: { "secret" => [ "RAILS_MASTER_KEY" ] } }
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
  end

  test "run" do
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-web.env --health-cmd \"(curl -f http://localhost:3000/up || exit 1) && (stat /tmp/kamal-cord/cord > /dev/null || exit 1)\" --health-interval \"1s\" --volume $(pwd)/.kamal/cords/app-web-12345678901234567890123456789012:/tmp/kamal-cord --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.app-web.priority=\"2\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with hostname" do
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --hostname myhost -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-web.env --health-cmd \"(curl -f http://localhost:3000/up || exit 1) && (stat /tmp/kamal-cord/cord > /dev/null || exit 1)\" --health-interval \"1s\" --volume $(pwd)/.kamal/cords/app-web-12345678901234567890123456789012:/tmp/kamal-cord --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.app-web.priority=\"2\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run(hostname: "myhost").join(" ")
  end

  test "run with volumes" do
    @config[:volumes] = ["/local/path:/container/path" ]

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-web.env --health-cmd \"(curl -f http://localhost:3000/up || exit 1) && (stat /tmp/kamal-cord/cord > /dev/null || exit 1)\" --health-interval \"1s\" --volume $(pwd)/.kamal/cords/app-web-12345678901234567890123456789012:/tmp/kamal-cord --log-opt max-size=\"10m\" --volume /local/path:/container/path --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.app-web.priority=\"2\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom healthcheck path" do
    @config[:healthcheck] = { "path" => "/healthz" }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-web.env --health-cmd \"(curl -f http://localhost:3000/healthz || exit 1) && (stat /tmp/kamal-cord/cord > /dev/null || exit 1)\" --health-interval \"1s\" --volume $(pwd)/.kamal/cords/app-web-12345678901234567890123456789012:/tmp/kamal-cord --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.app-web.priority=\"2\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom healthcheck command" do
    @config[:healthcheck] = { "cmd" => "/bin/up" }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-web.env --health-cmd \"(/bin/up) && (stat /tmp/kamal-cord/cord > /dev/null || exit 1)\" --health-interval \"1s\" --volume $(pwd)/.kamal/cords/app-web-12345678901234567890123456789012:/tmp/kamal-cord --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.app-web.priority=\"2\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with role-specific healthcheck options" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "healthcheck" => { "cmd" => "/bin/healthy" } } }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-web.env --health-cmd \"(/bin/healthy) && (stat /tmp/kamal-cord/cord > /dev/null || exit 1)\" --health-interval \"1s\" --volume $(pwd)/.kamal/cords/app-web-12345678901234567890123456789012:/tmp/kamal-cord --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.app-web.priority=\"2\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom options" do
    @config[:servers] = { "web" => [ "1.1.1.1" ], "jobs" => { "hosts" => [ "1.1.1.2" ], "cmd" => "bin/jobs", "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-jobs-999 -e KAMAL_CONTAINER_NAME=\"app-jobs-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-jobs.env --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"jobs\" --mount \"somewhere\" --cap-add dhh/app:999 bin/jobs",
      new_command(role: "jobs").run.join(" ")
  end

  test "run with logging config" do
    @config[:logging] = { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => "3" } }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/env/roles/app-web.env --health-cmd \"(curl -f http://localhost:3000/up || exit 1) && (stat /tmp/kamal-cord/cord > /dev/null || exit 1)\" --health-interval \"1s\" --volume $(pwd)/.kamal/cords/app-web-12345678901234567890123456789012:/tmp/kamal-cord --log-driver \"local\" --log-opt max-size=\"100m\" --log-opt max-file=\"3\" --label service=\"app\" --label role=\"web\" --label traefik.http.services.app-web.loadbalancer.server.scheme=\"http\" --label traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.app-web.priority=\"2\" --label traefik.http.middlewares.app-web-retry.retry.attempts=\"5\" --label traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\" --label traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\" dhh/app:999",
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

  test "stop_containers_async" do
    expected_command = "nohup sh -c 'echo \"container1\ncontainer2\" | xargs docker stop' > /dev/null 2>&1 & disown"
    assert_equal expected_command, new_command.stop_containers_async(['container1', 'container2']).join(" ")
  end

  test "stop_containers_async with custom stop wait time" do
    @config[:stop_wait_time] = 30
    expected_command = "nohup sh -c 'echo \"container1\ncontainer2\" | xargs docker stop -t 30' > /dev/null 2>&1 & disown"
    assert_equal expected_command, new_command.stop_containers_async(['container1', 'container2']).join(" ")
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
      "docker run --rm --env-file .kamal/env/roles/app-web.env dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in new container with custom options" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_equal \
      "docker run --rm --env-file .kamal/env/roles/app-web.env --mount \"somewhere\" --cap-add dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-web-999 bin/rails db:setup",
      new_command.execute_in_existing_container("bin/rails", "db:setup").join(" ")
  end

  test "execute in new container over ssh" do
    assert_match %r|docker run -it --rm --env-file .kamal/env/roles/app-web.env dhh/app:999 bin/rails c|,
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", host: "app-1")
  end

  test "execute in new container with custom options over ssh" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_match %r|docker run -it --rm --env-file .kamal/env/roles/app-web.env --mount \"somewhere\" --cap-add dhh/app:999 bin/rails c|,
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", host: "app-1")
  end

  test "execute in existing container over ssh" do
    assert_match %r|docker exec -it app-web-999 bin/rails c|,
      new_command.execute_in_existing_container_over_ssh("bin/rails", "c", host: "app-1")
  end

  test "run over ssh" do
    assert_equal "ssh -t root@1.1.1.1 -p 22 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with custom user" do
    @config[:ssh] = { "user" => "app" }
    assert_equal "ssh -t app@1.1.1.1 -p 22 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with custom port" do
    @config[:ssh] = { "port" => "2222" }
    assert_equal "ssh -t root@1.1.1.1 -p 2222 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with proxy" do
    @config[:ssh] = { "proxy" => "2.2.2.2" }
    assert_equal "ssh -J root@2.2.2.2 -t root@1.1.1.1 -p 22 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with proxy user" do
    @config[:ssh] = { "proxy" => "app@2.2.2.2" }
    assert_equal "ssh -J app@2.2.2.2 -t root@1.1.1.1 -p 22 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with custom user with proxy" do
    @config[:ssh] = { "user" => "app", "proxy" => "2.2.2.2" }
    assert_equal "ssh -J root@2.2.2.2 -t app@1.1.1.1 -p 22 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
  end

  test "run over ssh with proxy_command" do
    @config[:ssh] = { "proxy_command" => "ssh -W %h:%p user@proxy-server" }
    assert_equal "ssh -o ProxyCommand='ssh -W %h:%p user@proxy-server' -t root@1.1.1.1 -p 22 'ls'", new_command.run_over_ssh("ls", host: "1.1.1.1")
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
      "docker ps --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest --format \"{{.Names}}\" | while read line; do echo ${line#app-web-}; done",
      new_command.current_running_version.join(" ")
  end

  test "list_versions" do
    assert_equal \
      "docker ps --filter label=service=app --filter label=role=web --format \"{{.Names}}\" | while read line; do echo ${line#app-web-}; done",
      new_command.list_versions.join(" ")

    assert_equal \
      "docker ps --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest --format \"{{.Names}}\" | while read line; do echo ${line#app-web-}; done",
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

  test "tag_current_image_as_latest" do
    assert_equal \
      "docker tag dhh/app:999 dhh/app:latest",
      new_command.tag_current_image_as_latest.join(" ")
  end

  test "make_env_directory" do
    assert_equal "mkdir -p .kamal/env/roles", new_command.make_env_directory.join(" ")
  end

  test "remove_env_file" do
    assert_equal "rm -f .kamal/env/roles/app-web.env", new_command.remove_env_file.join(" ")
  end

  test "cord" do
    assert_equal "docker inspect -f '{{ range .Mounts }}{{printf \"%s %s\\n\" .Source .Destination}}{{ end }}' app-web-123 | awk '$2 == \"/tmp/kamal-cord\" {print $1}'", new_command.cord(version: 123).join(" ")
  end

  test "tie cord" do
    assert_equal "mkdir -p . ; touch cordfile", new_command.tie_cord("cordfile").join(" ")
    assert_equal "mkdir -p corddir ; touch corddir/cordfile", new_command.tie_cord("corddir/cordfile").join(" ")
    assert_equal "mkdir -p /corddir ; touch /corddir/cordfile", new_command.tie_cord("/corddir/cordfile").join(" ")
  end

  test "cut cord" do
    assert_equal "rm -r corddir", new_command.cut_cord("corddir").join(" ")
  end

  test "extract assets" do
    assert_equal [
      :mkdir, "-p", ".kamal/assets/extracted/app-web-999", "&&",
      :docker, :stop, "-t 1", "app-web-assets", "2> /dev/null", "|| true", "&&",
      :docker, :run, "--name", "app-web-assets", "--detach", "--rm", "dhh/app:latest", "sleep 1000000", "&&",
      :docker, :cp, "-L", "app-web-assets:/public/assets/.", ".kamal/assets/extracted/app-web-999", "&&",
      :docker, :stop, "-t 1", "app-web-assets"
    ], new_command(asset_path: "/public/assets").extract_assets
  end

  test "sync asset volumes" do
    assert_equal [
      :mkdir, "-p", ".kamal/assets/volumes/app-web-999", ";",
      :cp, "-rnT", ".kamal/assets/extracted/app-web-999", ".kamal/assets/volumes/app-web-999"
    ], new_command(asset_path: "/public/assets").sync_asset_volumes

    assert_equal [
      :mkdir, "-p", ".kamal/assets/volumes/app-web-999", ";",
      :cp, "-rnT", ".kamal/assets/extracted/app-web-999", ".kamal/assets/volumes/app-web-999", ";",
      :cp, "-rnT", ".kamal/assets/extracted/app-web-999", ".kamal/assets/volumes/app-web-998", "|| true", ";",
      :cp, "-rnT", ".kamal/assets/extracted/app-web-998", ".kamal/assets/volumes/app-web-999", "|| true",
    ], new_command(asset_path: "/public/assets").sync_asset_volumes(old_version: 998)
  end

  test "clean up assets" do
    assert_equal [
      :find, ".kamal/assets/extracted", "-maxdepth 1", "-name", "'app-web-*'", "!", "-name", "app-web-999", "-exec rm -rf \"{}\" +", ";",
      :find, ".kamal/assets/volumes", "-maxdepth 1", "-name", "'app-web-*'", "!", "-name", "app-web-999", "-exec rm -rf \"{}\" +"
    ], new_command(asset_path: "/public/assets").clean_up_assets
  end

  private
    def new_command(role: "web", **additional_config)
      Kamal::Commands::App.new(Kamal::Configuration.new(@config.merge(additional_config), destination: @destination, version: "999"), role: role)
    end
end
