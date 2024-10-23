require "test_helper"

class CommandsAppTest < ActiveSupport::TestCase
  setup do
    setup_test_secrets("secrets" => "RAILS_MASTER_KEY=456")

    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: { "web" => [ "1.1.1.1" ], "workers" => [ "1.1.1.2" ] }, env: { "secret" => [ "RAILS_MASTER_KEY" ] }, builder: { "arch" => "amd64" } }
  end

  teardown do
    teardown_test_secrets
  end

  test "run" do
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --network kamal -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label destination dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with hostname" do
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --network kamal --hostname myhost -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label destination dhh/app:999",
      new_command.run(hostname: "myhost").join(" ")
  end

  test "run with volumes" do
    @config[:volumes] = [ "/local/path:/container/path" ]

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --network kamal -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" --volume /local/path:/container/path --label service=\"app\" --label role=\"web\" --label destination dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with custom options" do
    @config[:servers] = { "web" => [ "1.1.1.1" ], "jobs" => { "hosts" => [ "1.1.1.2" ], "cmd" => "bin/jobs", "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_equal \
      "docker run --detach --restart unless-stopped --name app-jobs-999 --network kamal -e KAMAL_CONTAINER_NAME=\"app-jobs-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/apps/app/env/roles/jobs.env --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"jobs\" --label destination --mount \"somewhere\" --cap-add dhh/app:999 bin/jobs",
      new_command(role: "jobs", host: "1.1.1.2").run.join(" ")
  end

  test "run with logging config" do
    @config[:logging] = { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => "3" } }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --network kamal -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/apps/app/env/roles/web.env --log-driver \"local\" --log-opt max-size=\"100m\" --log-opt max-file=\"3\" --label service=\"app\" --label role=\"web\" --label destination dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with role logging config" do
    @config[:logging] = { "driver" => "local", "options" => { "max-size" => "10m", "max-file" => "3" } }
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "logging" => { "driver" => "local", "options" => { "max-size" => "100m" } } } }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --network kamal -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env-file .kamal/apps/app/env/roles/web.env --log-driver \"local\" --log-opt max-size=\"100m\" --log-opt max-file=\"3\" --label service=\"app\" --label role=\"web\" --label destination dhh/app:999",
      new_command.run.join(" ")
  end

  test "run with tags" do
    @config[:servers] = [ { "1.1.1.1" => "tag1" } ]
    @config[:env]["tags"] = { "tag1" => { "ENV1" => "value1" } }

    assert_equal \
      "docker run --detach --restart unless-stopped --name app-web-999 --network kamal -e KAMAL_CONTAINER_NAME=\"app-web-999\" -e KAMAL_VERSION=\"999\" --env ENV1=\"value1\" --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" --label service=\"app\" --label role=\"web\" --label destination dhh/app:999",
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
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker stop",
      new_command.stop.join(" ")
  end

  test "stop with custom drain timeout" do
    @config[:drain_timeout] = 20
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker stop",
      new_command.stop.join(" ")

    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=workers --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=workers --filter status=running --filter status=restarting' | head -1 | xargs docker stop -t 20",
      new_command(role: "workers").stop.join(" ")
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

  test "deploy" do
    assert_equal \
      "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"172.1.0.2:80\" --deploy-timeout=\"30s\" --drain-timeout=\"30s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"",
      new_command.deploy(target: "172.1.0.2").join(" ")
  end

  test "deploy with SSL" do
    @config[:proxy] = { "ssl" => true, "host" => "example.com" }

    assert_equal \
      "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"172.1.0.2:80\" --host=\"example.com\" --tls --deploy-timeout=\"30s\" --drain-timeout=\"30s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"",
      new_command.deploy(target: "172.1.0.2").join(" ")
  end

  test "deploy with SSL targeting multiple hosts" do
    @config[:proxy] = { "ssl" => true, "hosts" => [ "example.com", "anotherexample.com" ] }

    assert_equal \
      "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"172.1.0.2:80\" --host=\"example.com\" --host=\"anotherexample.com\" --tls --deploy-timeout=\"30s\" --drain-timeout=\"30s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"",
      new_command.deploy(target: "172.1.0.2").join(" ")
  end

  test "deploy with SSL false" do
    @config[:proxy] = { "ssl" => false }

    assert_equal \
      "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"172.1.0.2:80\" --deploy-timeout=\"30s\" --drain-timeout=\"30s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"",
      new_command.deploy(target: "172.1.0.2").join(" ")
  end

  test "remove" do
    assert_equal \
      "docker exec kamal-proxy kamal-proxy remove app-web",
      new_command.remove.join(" ")
  end



  test "logs" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps 2>&1",
      new_command.logs.join(" ")
  end

  test "logs with since" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps --since 5m 2>&1",
      new_command.logs(since: "5m").join(" ")
  end

  test "logs with lines" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps --tail 100 2>&1",
      new_command.logs(lines: "100").join(" ")
  end

  test "logs with since and lines" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps --since 5m --tail 100 2>&1",
      new_command.logs(since: "5m", lines: "100").join(" ")
  end

  test "logs with grep" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps 2>&1 | grep 'my-id'",
      new_command.logs(grep: "my-id").join(" ")
  end

  test "logs with grep and grep options" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps 2>&1 | grep 'my-id' -C 2",
      new_command.logs(grep: "my-id", grep_options: "-C 2").join(" ")
  end

  test "logs with since, grep and grep options" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps --since 5m 2>&1 | grep 'my-id' -C 2",
      new_command.logs(since: "5m", grep: "my-id", grep_options: "-C 2").join(" ")
  end

  test "logs with since and grep" do
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps --since 5m 2>&1 | grep 'my-id'",
      new_command.logs(since: "5m", grep: "my-id").join(" ")
  end

  test "follow logs" do
    assert_equal \
      "ssh -t root@app-1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --follow 2>&1'",
      new_command.follow_logs(host: "app-1")

    assert_equal \
      "ssh -t root@app-1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --follow 2>&1 | grep \"Completed\"'",
      new_command.follow_logs(host: "app-1", grep: "Completed")

    assert_equal \
      "ssh -t root@app-1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --tail 123 --follow 2>&1'",
      new_command.follow_logs(host: "app-1", lines: 123)

    assert_equal \
      "ssh -t root@app-1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --tail 123 --follow 2>&1 | grep \"Completed\"'",
      new_command.follow_logs(host: "app-1", lines: 123, grep: "Completed")

    assert_equal \
      "ssh -t root@app-1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --tail 123 --follow 2>&1 | grep \"Completed\"'",
      new_command.follow_logs(host: "app-1", timestamps: false, lines: 123, grep: "Completed")
  end


  test "execute in new container" do
    assert_equal \
      "docker run --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup", env: {}).join(" ")
  end

  test "execute in new container with env" do
    assert_equal \
      "docker run --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env --env foo=\"bar\" dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup", env: { "foo" => "bar" }).join(" ")
  end

  test "execute in new detached container" do
    assert_equal \
      "docker run --detach --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup", detach: true, env: {}).join(" ")
  end

  test "execute in new container with tags" do
    @config[:servers] = [ { "1.1.1.1" => "tag1" } ]
    @config[:env]["tags"] = { "tag1" => { "ENV1" => "value1" } }

    assert_equal \
      "docker run --rm --network kamal --env ENV1=\"value1\" --env-file .kamal/apps/app/env/roles/web.env dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup", env: {}).join(" ")
  end

  test "execute in new container with custom options" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_equal \
      "docker run --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env --mount \"somewhere\" --cap-add dhh/app:999 bin/rails db:setup",
      new_command.execute_in_new_container("bin/rails", "db:setup", env: {}).join(" ")
  end

  test "execute in existing container" do
    assert_equal \
      "docker exec app-web-999 bin/rails db:setup",
      new_command.execute_in_existing_container("bin/rails", "db:setup", env: {}).join(" ")
  end

  test "execute in existing container with env" do
    assert_equal \
      "docker exec --env foo=\"bar\" app-web-999 bin/rails db:setup",
      new_command.execute_in_existing_container("bin/rails", "db:setup", env: { "foo" => "bar" }).join(" ")
  end

  test "execute in new container over ssh" do
    assert_match %r{docker run -it --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env dhh/app:999 bin/rails c},
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", env: {})
  end

  test "execute in new container over ssh with tags" do
    @config[:servers] = [ { "1.1.1.1" => "tag1" } ]
    @config[:env]["tags"] = { "tag1" => { "ENV1" => "value1" } }

    assert_equal "ssh -t root@1.1.1.1 -p 22 'docker run -it --rm --network kamal --env ENV1=\"value1\" --env-file .kamal/apps/app/env/roles/web.env dhh/app:999 bin/rails c'",
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", env: {})
  end

  test "execute in new container with custom options over ssh" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "options" => { "mount" => "somewhere", "cap-add" => true } } }
    assert_match %r{docker run -it --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env --mount \"somewhere\" --cap-add dhh/app:999 bin/rails c},
      new_command.execute_in_new_container_over_ssh("bin/rails", "c", env: {})
  end

  test "execute in existing container over ssh" do
    assert_match %r{docker exec -it app-web-999 bin/rails c},
      new_command.execute_in_existing_container_over_ssh("bin/rails", "c", env: {})
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
    "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1",
      new_command.current_running_container_id.join(" ")
  end

  test "current_running_container_id with destination" do
    @destination = "staging"
    assert_equal \
      "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination=staging --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest-staging --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination=staging --filter label=role=web --filter status=running --filter status=restarting' | head -1",
      new_command.current_running_container_id.join(" ")
  end

  test "container_id_for" do
    assert_equal \
      "docker container ls --all --filter name=^app-999$ --quiet",
      new_command.container_id_for(container_name: "app-999").join(" ")
  end

  test "current_running_version" do
    assert_equal \
      "sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done",
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

  test "tag_latest_image" do
    assert_equal \
      "docker tag dhh/app:999 dhh/app:latest",
      new_command.tag_latest_image.join(" ")
  end

  test "tag_latest_image with destination" do
    @destination = "staging"
    assert_equal \
      "docker tag dhh/app:999 dhh/app:latest-staging",
      new_command.tag_latest_image.join(" ")
  end

  test "extract assets" do
    assert_equal [
      :mkdir, "-p", ".kamal/apps/app/assets/extracted/web-999", "&&",
      :docker, :stop, "-t 1", "app-web-assets", "2> /dev/null", "|| true", "&&",
      :docker, :run, "--name", "app-web-assets", "--detach", "--rm", "--entrypoint", "sleep", "dhh/app:999", "1000000", "&&",
      :docker, :cp, "-L", "app-web-assets:/public/assets/.", ".kamal/apps/app/assets/extracted/web-999", "&&",
      :docker, :stop, "-t 1", "app-web-assets"
    ], new_command(asset_path: "/public/assets").extract_assets
  end

  test "sync asset volumes" do
    assert_equal [
      :mkdir, "-p", ".kamal/apps/app/assets/volumes/web-999", ";",
      :cp, "-rnT", ".kamal/apps/app/assets/extracted/web-999", ".kamal/apps/app/assets/volumes/web-999"
    ], new_command(asset_path: "/public/assets").sync_asset_volumes

    assert_equal [
      :mkdir, "-p", ".kamal/apps/app/assets/volumes/web-999", ";",
      :cp, "-rnT", ".kamal/apps/app/assets/extracted/web-999", ".kamal/apps/app/assets/volumes/web-999", ";",
      :cp, "-rnT", ".kamal/apps/app/assets/extracted/web-999", ".kamal/apps/app/assets/volumes/web-998", "|| true", ";",
      :cp, "-rnT", ".kamal/apps/app/assets/extracted/web-998", ".kamal/apps/app/assets/volumes/web-999", "|| true"
    ], new_command(asset_path: "/public/assets").sync_asset_volumes(old_version: 998)
  end

  test "clean up assets" do
    assert_equal [
      :find, ".kamal/apps/app/assets/extracted", "-maxdepth 1", "-name", "'web-*'", "!", "-name", "web-999", "-exec rm -rf \"{}\" +", ";",
      :find, ".kamal/apps/app/assets/volumes", "-maxdepth 1", "-name", "'web-*'", "!", "-name", "web-999", "-exec rm -rf \"{}\" +"
    ], new_command(asset_path: "/public/assets").clean_up_assets
  end

  private
    def new_command(role: "web", host: "1.1.1.1", **additional_config)
      config = Kamal::Configuration.new(@config.merge(additional_config), destination: @destination, version: "999")
      Kamal::Commands::App.new(config, role: config.role(role), host: host)
    end
end
