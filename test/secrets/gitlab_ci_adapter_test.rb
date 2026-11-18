require "test_helper"

class GitlabCiAdapterTest < SecretAdapterTestCase
  test "fetch with specific secrets and scope" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: true)

    stub_ticks
      .with("glab variable list --output json --per-page 100 --page 1")
      .returns(<<~JSON)
        [
          {"key":"DATABASE_URL","value":"postgres://localhost/myapp_production","environment_scope":"production"},
          {"key":"DATABASE_URL","value":"postgres://localhost/myapp_staging","environment_scope":"staging"},
          {"key":"DATABASE_URL","value":"postgres://localhost/myapp","environment_scope":"*"},
          {"key":"RAILS_MASTER_KEY","value":"abc123production","environment_scope":"production"},
          {"key":"RAILS_MASTER_KEY","value":"abc123staging","environment_scope":"staging"},
          {"key":"SECRET_KEY_BASE","value":"globalsecret","environment_scope":"*"}
        ]
      JSON

    json = JSON.parse(run_command("fetch", "--from", "staging", "DATABASE_URL", "RAILS_MASTER_KEY"))

    expected_json = {
      "DATABASE_URL" => "postgres://localhost/myapp_staging",
      "RAILS_MASTER_KEY" => "abc123staging"
    }

    assert_equal expected_json, json
  end

  test "fetch falls back to default scope" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: true)

    stub_ticks
      .with("glab variable list --output json --per-page 100 --page 1")
      .returns(<<~JSON)
        [
          {"key":"SECRET_KEY_BASE","value":"globalsecret","environment_scope":"*"},
          {"key":"DATABASE_URL","value":"postgres://localhost/myapp_staging","environment_scope":"staging"}
        ]
      JSON

    json = JSON.parse(run_command("fetch", "--from", "staging", "SECRET_KEY_BASE", "DATABASE_URL"))

    expected_json = {
      "SECRET_KEY_BASE" => "globalsecret",
      "DATABASE_URL" => "postgres://localhost/myapp_staging"
    }

    assert_equal expected_json, json
  end

  test "fetch falls back to wildcard when scoped variant is missing" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: true)

    stub_ticks
      .with("glab variable list --output json --per-page 100 --page 1")
      .returns(<<~JSON)
        [
          {"key":"SECRET_KEY_BASE","value":"globalsecret","environment_scope":"*"},
          {"key":"DATABASE_URL","value":"postgres://localhost/myapp_staging","environment_scope":"staging"}
        ]
      JSON

    json = JSON.parse(run_command("fetch", "--from", "staging", "SECRET_KEY_BASE"))

    expected_json = {
      "SECRET_KEY_BASE" => "globalsecret"
    }

    assert_equal expected_json, json
  end

  test "fetch without scope returns only default scope" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: true)

    stub_ticks
      .with("glab variable list --output json --per-page 100 --page 1")
      .returns(<<~JSON)
        [
          {"key":"SECRET_KEY_BASE","value":"globalsecret","environment_scope":"*"},
          {"key":"DATABASE_URL","value":"postgres://localhost/myapp_staging","environment_scope":"staging"}
        ]
      JSON

    json = JSON.parse(run_command("fetch", "SECRET_KEY_BASE", "DATABASE_URL"))

    expected_json = {
      "SECRET_KEY_BASE" => "globalsecret"
    }

    assert_equal expected_json, json
  end

  test "fetch all secrets" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: true)

    stub_ticks
      .with("glab variable list --output json --per-page 100 --page 1")
      .returns(<<~JSON)
        [
          {"key":"SECRET_KEY_BASE","value":"globalsecret","environment_scope":"*"},
          {"key":"DATABASE_URL","value":"postgres://localhost/myapp_staging","environment_scope":"staging"}
        ]
      JSON

    json = JSON.parse(run_command("fetch", "--from", "staging"))

    expected_json = {
      "SECRET_KEY_BASE" => "globalsecret",
      "DATABASE_URL" => "postgres://localhost/myapp_staging"
    }

    assert_equal expected_json, json
  end

  test "fetch with pagination" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: true)

    page1 = (1..100).map { |i| { key: "VAR_#{i}", value: "val_#{i}", environment_scope: "*" } }

    stub_ticks
      .with("glab variable list --output json --per-page 100 --page 1")
      .returns(JSON.generate(page1))

    stub_ticks
      .with("glab variable list --output json --per-page 100 --page 2")
      .returns(<<~JSON)
        [
          {"key":"LAST_VAR","value":"last_value","environment_scope":"*"}
        ]
      JSON

    json = JSON.parse(run_command("fetch", "--from", "production", "VAR_1", "LAST_VAR"))

    expected_json = {
      "VAR_1" => "val_1",
      "LAST_VAR" => "last_value"
    }

    assert_equal expected_json, json
  end

  test "fetch with glab variable list failure" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: true)
    stub_ticks_with("glab variable list --output json --per-page 100 --page 1", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "SECRET1")
    end

    assert_equal "Failed to list GitLab CI/CD variables", error.message
  end

  test "fetch without CLI installed" do
    stub_ticks_with("glab --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "SECRET1")
    end

    assert_equal "glab CLI is not installed", error.message
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "gitlab-ci" ]
      end
    end
end
