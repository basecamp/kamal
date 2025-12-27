require "test_helper"

class CommandsLoadbalancerTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app",
      image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ] },
      builder: { "arch" => "amd64" },
      proxy: { "loadbalancer" => "lb.example.com", "hosts" => [ "app.example.com" ] }
    }
  end

  test "run" do
    assert_equal \
      "echo basecamp/kamal-proxy:#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION} | xargs docker run --name load-balancer --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --label org.opencontainers.image.title=kamal-loadbalancer --volume kamal-loadbalancer-config:/home/kamal-loadbalancer/.config/kamal-loadbalancer",
      new_command.run.join(" ")
  end

  test "start" do
    assert_equal \
      "docker container start load-balancer",
      new_command.start.join(" ")
  end

  test "stop" do
    assert_equal \
      "docker container stop load-balancer",
      new_command.stop.join(" ")
  end

  test "start_or_run" do
    assert_equal \
      "docker container start load-balancer || echo basecamp/kamal-proxy:#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION} | xargs docker run --name load-balancer --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --label org.opencontainers.image.title=kamal-loadbalancer --volume kamal-loadbalancer-config:/home/kamal-loadbalancer/.config/kamal-loadbalancer",
      new_command.start_or_run.join(" ")
  end

  test "deploy with targets" do
    assert_equal \
      "docker exec load-balancer kamal-proxy deploy app --target=1.1.1.1:80,1.1.1.2:80 --host=app.example.com",
      new_command.deploy(targets: [ "1.1.1.1", "1.1.1.2" ]).join(" ")
  end

  test "deploy with targets and ssl" do
    @config[:proxy]["ssl"] = true
    assert_equal \
      "docker exec load-balancer kamal-proxy deploy app --target=1.1.1.1:80,1.1.1.2:80 --host=app.example.com --tls",
      new_command.deploy(targets: [ "1.1.1.1", "1.1.1.2" ]).join(" ")
  end

  test "deploy with multiple hosts" do
    @config[:proxy]["hosts"] = [ "app1.example.com", "app2.example.com" ]
    assert_equal \
      "docker exec load-balancer kamal-proxy deploy app --target=1.1.1.1:80 --host=app1.example.com,app2.example.com",
      new_command.deploy(targets: [ "1.1.1.1" ]).join(" ")
  end

  test "info" do
    assert_equal \
      "docker ps --filter name=^load-balancer$",
      new_command.info.join(" ")
  end

  test "version" do
    assert_equal \
      "docker inspect load-balancer --format '{{.Config.Image}}' | cut -d: -f2",
      new_command.version.join(" ")
  end

  test "logs" do
    assert_equal \
      "docker logs load-balancer --timestamps 2>&1",
      new_command.logs.join(" ")
  end

  test "logs since 2h" do
    assert_equal \
      "docker logs load-balancer --since 2h --timestamps 2>&1",
      new_command.logs(since: "2h").join(" ")
  end

  test "logs last 10 lines" do
    assert_equal \
      "docker logs load-balancer --tail 10 --timestamps 2>&1",
      new_command.logs(lines: 10).join(" ")
  end

  test "logs without timestamps" do
    assert_equal \
      "docker logs load-balancer 2>&1",
      new_command.logs(timestamps: false).join(" ")
  end

  test "logs with grep" do
    assert_equal \
      "docker logs load-balancer --timestamps 2>&1 | grep 'error'",
      new_command.logs(grep: "error").join(" ")
  end

  test "follow_logs" do
    assert_equal \
      "ssh -t root@lb.example.com -p 22 'docker logs load-balancer --timestamps --tail 10 --follow 2>&1'",
      new_command.follow_logs(host: "lb.example.com")
  end

  test "follow_logs with grep" do
    assert_equal \
      "ssh -t root@lb.example.com -p 22 'docker logs load-balancer --timestamps --tail 10 --follow 2>&1 | grep \"error\"'",
      new_command.follow_logs(host: "lb.example.com", grep: "error")
  end

  test "remove_container" do
    assert_equal \
      "docker container prune --force --filter label=org.opencontainers.image.title=kamal-loadbalancer",
      new_command.remove_container.join(" ")
  end

  test "remove_image" do
    assert_equal \
      "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-loadbalancer",
      new_command.remove_image.join(" ")
  end

  test "ensure_directory" do
    assert_equal \
      "mkdir -p .kamal/loadbalancer",
      new_command.ensure_directory.join(" ")
  end

  test "remove_directory" do
    assert_equal \
      "rm -r .kamal/loadbalancer",
      new_command.remove_directory.join(" ")
  end

  private
    def new_command
      config = Kamal::Configuration.new(@config, version: "123")
      loadbalancer_config = Kamal::Configuration::Loadbalancer.new(
        config: config,
        proxy_config: config.proxy.proxy_config,
        secrets: config.secrets
      )
      Kamal::Commands::Loadbalancer.new(config, loadbalancer_config: loadbalancer_config)
    end
end
