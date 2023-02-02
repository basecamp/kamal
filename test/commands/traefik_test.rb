require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/traefik"

class CommandsTraefikTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "run" do
    assert_equal \
      [:docker, :run, "--name traefik", "-d", "--restart unless-stopped", "-p 80:80", "-v /var/run/docker.sock:/var/run/docker.sock", "traefik", "--providers.docker", "--log.level=DEBUG", "--accesslog.format", "json", "--metrics.prometheus.buckets", "0.1,0.3,1.2,5.0"],
      new_command.run
  end

  test "traefik start" do
    assert_equal \
      [:docker, :container, :start, 'traefik'], new_command.start
  end

  test "traefik stop" do
    assert_equal \
      [:docker, :container, :stop, 'traefik'], new_command.stop
  end

  test "traefik info" do
    assert_equal \
      [:docker, :ps, '--filter', 'name=traefik'], new_command.info
  end

  test "traefik logs" do
    assert_equal \
      [:docker, :logs, 'traefik', '-t', '2>&1'], new_command.logs
  end

  test "traefik logs since 2h" do
    assert_equal \
      [:docker, :logs, 'traefik', ' --since 2h', '-t', '2>&1'], new_command.logs(since: '2h')
  end

  test "traefik logs last 10 lines" do
    assert_equal \
      [:docker, :logs, 'traefik', ' -n 10', '-t', '2>&1'], new_command.logs(lines: 10)
  end

  test "traefik logs with grep hello!" do
    assert_equal \
      [:docker, :logs, 'traefik', '-t', '2>&1', "|", "grep 'hello!'"], new_command.logs(grep: 'hello!')
  end

  test "traefik remove container" do
    assert_equal \
      [:docker, :container, :prune, "-f", "--filter", "label=org.opencontainers.image.title=Traefik"], new_command.remove_container
  end

  test "traefik remove image" do
    assert_equal \
    [:docker, :image, :prune, "-a", "-f", "--filter", "label=org.opencontainers.image.title=Traefik"], new_command.remove_image
  end

  test "traefik follow logs" do
    assert_equal \
    "ssh -t root@1.1.1.1 'docker logs traefik -t -n 10 -f 2>&1'", new_command.follow_logs(host: @config[:servers].first)
  end

  test "traefik follow logs with grep hello!" do
    assert_equal \
    "ssh -t root@1.1.1.1 'docker logs traefik -t -n 10 -f 2>&1 | grep \"hello!\"'", new_command.follow_logs(host: @config[:servers].first, grep: 'hello!')
  end

  private
    def new_command
      Mrsk::Commands::Traefik.new(Mrsk::Configuration.new(@config, tag: "123"))
    end
end
