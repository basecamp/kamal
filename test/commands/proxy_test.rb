require "test_helper"

class CommandsProxyTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], builder: { "arch" => "amd64" }
    }

    ENV["EXAMPLE_API_KEY"] = "456"
  end

  teardown do
    ENV.delete("EXAMPLE_API_KEY")
  end

  test "run" do
    assert_equal \
      "echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config",
      new_command.run.join(" ")
  end

  test "run without configuration" do
    @config.delete(:proxy)

    assert_equal \
      "echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config",
      new_command.run.join(" ")
  end

  test "proxy start" do
    assert_equal \
      "docker container start kamal-proxy",
      new_command.start.join(" ")
  end

  test "proxy stop" do
    assert_equal \
      "docker container stop kamal-proxy",
      new_command.stop.join(" ")
  end

  test "proxy info" do
    assert_equal \
      "docker ps --filter 'name=^kamal-proxy$'",
      new_command.info.join(" ")
  end

  test "proxy logs" do
    assert_equal \
      "docker logs kamal-proxy --timestamps 2>&1",
      new_command.logs.join(" ")
  end

  test "proxy logs since 2h" do
    assert_equal \
      "docker logs kamal-proxy --since 2h --timestamps 2>&1",
      new_command.logs(since: "2h").join(" ")
  end

  test "proxy logs last 10 lines" do
    assert_equal \
      "docker logs kamal-proxy --tail 10 --timestamps 2>&1",
      new_command.logs(lines: 10).join(" ")
  end

  test "proxy logs without timestamps" do
    assert_equal \
      "docker logs kamal-proxy 2>&1",
      new_command.logs(timestamps: false).join(" ")
  end

  test "proxy logs with grep hello!" do
    assert_equal \
      "docker logs kamal-proxy --timestamps 2>&1 | grep 'hello!'",
      new_command.logs(grep: "hello!").join(" ")
  end

  test "proxy remove container" do
    assert_equal \
      "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy",
      new_command.remove_container.join(" ")
  end

  test "proxy remove image" do
    assert_equal \
      "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy",
      new_command.remove_image.join(" ")
  end

  test "proxy follow logs" do
    assert_equal \
      "ssh -t root@1.1.1.1 -p 22 'docker logs kamal-proxy --timestamps --tail 10 --follow 2>&1'",
      new_command.follow_logs(host: @config[:servers].first)
  end

  test "proxy follow logs with grep hello!" do
    assert_equal \
      "ssh -t root@1.1.1.1 -p 22 'docker logs kamal-proxy --timestamps --tail 10 --follow 2>&1 | grep \"hello!\"'",
      new_command.follow_logs(host: @config[:servers].first, grep: "hello!")
  end

  test "version" do
    assert_equal \
      "docker inspect kamal-proxy --format '{{.Config.Image}}' | awk -F: '{print $NF}'",
      new_command.version.join(" ")
  end

  test "ensure_proxy_directory" do
    assert_equal \
      "mkdir -p .kamal/proxy",
      new_command.ensure_proxy_directory.join(" ")
  end

  test "read_boot_options" do
    assert_equal \
      "cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\"",
      new_command.read_boot_options.join(" ")
  end

  test "read_image" do
    assert_equal \
      "cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"",
      new_command.read_image.join(" ")
  end

  test "read_image_version" do
    assert_equal \
      "cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\"",
      new_command.read_image_version.join(" ")
  end

  test "read_run_command" do
    assert_equal \
      "cat .kamal/proxy/run_command 2> /dev/null || echo \"\"",
      new_command.read_run_command.join(" ")
  end

  test "reset_boot_options" do
    assert_equal \
      "rm .kamal/proxy/options",
      new_command.reset_boot_options.join(" ")
  end

  test "reset_image" do
    assert_equal \
      "rm .kamal/proxy/image",
      new_command.reset_image.join(" ")
  end

  test "reset_image_version" do
    assert_equal \
      "rm .kamal/proxy/image_version",
      new_command.reset_image_version.join(" ")
  end

  test "ensure_apps_config_directory" do
    assert_equal \
      "mkdir -p .kamal/proxy/apps-config",
      new_command.ensure_apps_config_directory.join(" ")
  end

  test "reset_run_command" do
    assert_equal \
      "rm .kamal/proxy/run_command",
      new_command.reset_run_command.join(" ")
  end

  test "registry run config" do
    @config[:proxy] = { "run" => { "registry" => "registry:4443" } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=10m registry:4443/basecamp/kamal-proxy:v0.9.2 kamal-proxy run",
      new_command.run.join(" ")
  end

  test "repository run config" do
    @config[:proxy] = { "run" => { "repository" => "custom/repo" } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=10m custom/repo:v0.9.2 kamal-proxy run",
      new_command.run.join(" ")
  end

  test "image_version run config" do
    @config[:proxy] = { "run" => { "version" => "v1.2.3" } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=10m basecamp/kamal-proxy:v1.2.3 kamal-proxy run",
      new_command.run.join(" ")
  end

  test "bind_ips run config" do
    @config[:proxy] = { "run" => { "bind_ips" => [ "0.0.0.0", "127.0.0.1" ] } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 0.0.0.0:80:80 --publish 0.0.0.0:443:443 --publish 127.0.0.1:80:80 --publish 127.0.0.1:443:443 --log-opt max-size=10m basecamp/kamal-proxy:v0.9.2 kamal-proxy run",
      new_command.run.join(" ")
  end

  test "log_max_size run config" do
    @config[:proxy] = { "run" => { "log_max_size" => "50m" } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=50m basecamp/kamal-proxy:v0.9.2 kamal-proxy run",
      new_command.run.join(" ")
  end

  test "debug run config" do
    @config[:proxy] = { "run" => { "debug" => true } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=10m basecamp/kamal-proxy:v0.9.2 kamal-proxy run --debug",
      new_command.run.join(" ")
  end

  test "metrics_port run config" do
    @config[:proxy] = { "run" => { "metrics_port" => 9090 } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=10m --expose=9090 basecamp/kamal-proxy:v0.9.2 kamal-proxy run --metrics-port \"9090\"",
      new_command.run.join(" ")
  end

  test "don't publish run config" do
    @config[:proxy] = { "run" => { "publish" => false } }
    assert_equal \
      "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --log-opt max-size=10m basecamp/kamal-proxy:v0.9.2 kamal-proxy run",
      new_command.run.join(" ")
  end

  private
    def new_command
      Kamal::Commands::Proxy.new(Kamal::Configuration.new(@config, version: "123"), host: "1.1.1.1")
    end
end
