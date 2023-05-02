require_relative "cli_test_case"

class CliPruneTest < CliTestCase
  test "all" do
    Mrsk::Cli::Prune.any_instance.expects(:containers)
    Mrsk::Cli::Prune.any_instance.expects(:images)

    run_command("all")
  end

  test "images" do
    run_command("images").tap do |output|
      assert_match /docker image prune --all --force --filter label=service=app --filter dangling=true on 1.1.1.\d/, output
    end
  end

  test "containers" do
    run_command("containers").tap do |output|
      assert_match /docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +6 | while read container_id; do docker rm $container_id; done on 1.1.1.\d/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Prune.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
