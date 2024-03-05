require_relative "cli_test_case"

class CliEnvTest < CliTestCase
  test "push" do
    run_command("push").tap do |output|
      assert_match "Running /usr/bin/env mkdir -p .kamal/env/roles on 1.1.1.1", output
      assert_match "Running /usr/bin/env mkdir -p .kamal/env/traefik on 1.1.1.1", output
      assert_match "Running /usr/bin/env mkdir -p .kamal/env/accessories on 1.1.1.1", output
      assert_match "Running /usr/bin/env mkdir -p .kamal/env/roles on 1.1.1.1", output
      assert_match "Running /usr/bin/env mkdir -p .kamal/env/traefik on 1.1.1.2", output
      assert_match "Running /usr/bin/env mkdir -p .kamal/env/accessories on 1.1.1.1", output
      assert_match ".kamal/env/roles/app-web.env", output
      assert_match ".kamal/env/roles/app-workers.env", output
      assert_match ".kamal/env/traefik/traefik.env", output
      assert_match ".kamal/env/accessories/app-redis.env", output
    end
  end

  test "delete" do
    run_command("delete").tap do |output|
      assert_match "Running /usr/bin/env rm -f .kamal/env/roles/app-web.env on 1.1.1.1", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/roles/app-web.env on 1.1.1.2", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/roles/app-workers.env on 1.1.1.3", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/roles/app-workers.env on 1.1.1.4", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/traefik/traefik.env on 1.1.1.1", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/traefik/traefik.env on 1.1.1.2", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/accessories/app-redis.env on 1.1.1.1", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/accessories/app-redis.env on 1.1.1.2", output
      assert_match "Running /usr/bin/env rm -f .kamal/env/accessories/app-mysql.env on 1.1.1.3", output
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Env.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
