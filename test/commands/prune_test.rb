require "test_helper"

class CommandsPruneTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      builder: { "arch" => "amd64" }
    }
  end

  test "dangling images" do
    assert_equal \
      "docker image prune --force --filter label=service=app",
      new_command.dangling_images.join(" ")
  end

  test "tagged images" do
    assert_equal \
      "docker image ls --filter label=service=app --format '{{.ID}} {{.Repository}}:{{.Tag}}' | grep -v -w \"$(docker container ls -a --format '{{.Image}}\\|' --filter label=service=app | tr -d '\\n')dhh/app:latest\\|dhh/app:<none>\" | while read image tag; do docker rmi $tag; done",
      new_command.tagged_images.join(" ")
  end

  test "app containers" do
    assert_equal \
      "docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +6 | while read container_id; do docker rm $container_id; done",
      new_command.app_containers(retain: 5).join(" ")

    assert_equal \
      "docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +4 | while read container_id; do docker rm $container_id; done",
      new_command.app_containers(retain: 3).join(" ")
  end

  private
    def new_command
      Kamal::Commands::Prune.new(Kamal::Configuration.new(@config, version: "123"))
    end
end
