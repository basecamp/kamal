require_relative "cli_test_case"

class CliPruneTest < CliTestCase
  test "all" do
    Kamal::Cli::Prune.any_instance.expects(:containers)
    Kamal::Cli::Prune.any_instance.expects(:images)

    run_command("all")
  end

  test "images" do
    run_command("images").tap do |output|
      assert_match "docker image prune --force --filter label=service=app on 1.1.1.", output
      assert_match "docker image ls --filter label=service=app --format '{{.ID}} {{.Repository}}:{{.Tag}}' | grep -v -w \"$(docker container ls -a --format '{{.Image}}\\|' --filter label=service=app | tr -d '\\n')dhh/app:latest\\|dhh/app:<none>\" | while read image tag; do docker rmi $tag; done on 1.1.1.", output
    end
  end

  test "containers" do
    run_command("containers").tap do |output|
      assert_match /docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +6 | while read container_id; do docker rm $container_id; done on 1.1.1.\d/, output
     end

    run_command("containers", "--retain", "10").tap do |output|
      assert_match /docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +11 | while read container_id; do docker rm $container_id; done on 1.1.1.\d/, output
    end

    assert_raises(RuntimeError, "retain must be at least 1") do
      run_command("containers", "--retain", "0")
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Prune.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
