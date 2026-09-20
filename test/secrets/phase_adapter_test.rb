require "test_helper"

class PhaseAdapterTest < SecretAdapterTestCase
  test "fetch without CLI installed" do
    stub_ticks_with("phase --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "SECRET1")
    end
    assert_equal "Phase CLI is not installed. Install it from https://docs.phase.dev/cli/install", error.message
  end

  test "fetch without authentication" do
    stub_ticks.with("phase --version 2> /dev/null")
    stub_ticks_with("phase users whoami 2> /dev/null", succeed: false)
    stub_ticks_with("phase auth", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "SECRET1")
    end
    assert_equal "Failed to authenticate with Phase. Run 'phase auth' to login", error.message
  end

  test "fetch specified secrets" do
    stub_ticks.with("phase --version 2> /dev/null")
    stub_authenticated
    stub_ticks
      .with("phase secrets get DB_PASSWORD --env production --app my-app --path /backend")
      .returns(<<~JSON)
        {
          "value": "supersecret123"
        }
      JSON
    stub_ticks
      .with("phase secrets get API_KEY --env production --app my-app --path /backend")
      .returns(<<~JSON)
        {
          "value": "api-key-456"
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "production/backend", "DB_PASSWORD", "API_KEY"))

    expected_json = {
      "production/backend/DB_PASSWORD" => "supersecret123",
      "production/backend/API_KEY" => "api-key-456"
    }

    assert_equal expected_json, json
  end

  test "fetch all secrets" do
    stub_ticks.with("phase --version 2> /dev/null")
    stub_authenticated
    stub_ticks
      .with("phase secrets export --env production --app my-app --path /backend --format json")
      .returns(<<~JSON)
        {
          "DB_PASSWORD": "supersecret123",
          "API_KEY": "api-key-456",
          "REDIS_URL": "redis://localhost:6379"
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "production/backend"))

    expected_json = {
      "production/backend/DB_PASSWORD" => "supersecret123",
      "production/backend/API_KEY" => "api-key-456",
      "production/backend/REDIS_URL" => "redis://localhost:6379"
    }

    assert_equal expected_json, json
  end

  test "fetch with nonexistent secret" do
    stub_ticks.with("phase --version 2> /dev/null")
    stub_authenticated
    stub_ticks_with("phase secrets get NONEXISTENT --env production --app my-app", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "--from", "production", "NONEXISTENT")
    end
    assert_equal "Could not read 'NONEXISTENT' from Phase app 'my-app'", error.message
  end

  test "fetch all with invalid app" do
    stub_ticks.with("phase --version 2> /dev/null")
    stub_authenticated
    stub_ticks_with("phase secrets export --env production --app invalid-app --format json", succeed: false)
      .returns("")

    error = assert_raises RuntimeError do
      run_command("fetch", "--from", "production", account: "invalid-app")
    end
    assert_equal "Failed to fetch secrets from Phase. Ensure app 'invalid-app' exists and you have access", error.message
  end

  private
    def stub_authenticated
      stub_ticks.with("phase users whoami 2> /dev/null")
    end

    def run_command(*command, account: "my-app")
      stdouted do
        args = [
          *command,
          "--adapter", "phase"
        ]
        args += [ "--account", account ] if account
        Kamal::Cli::Secrets.start(args)
      end
    end
end
