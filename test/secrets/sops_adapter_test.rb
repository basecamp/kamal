require "test_helper"

class SopsAdapterTest < SecretAdapterTestCase
  test "fetch top-level keys" do
    stub_ticks.with("sops --version 2> /dev/null")
    stub_ticks
      .with("sops --decrypt --output-type json -- secrets.enc.json")
      .returns(<<~JSON)
        {
          "DB_PASSWORD": "secret123",
          "API_KEY": "key456"
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "secrets.enc.json", "DB_PASSWORD", "API_KEY"))

    assert_equal({ "DB_PASSWORD" => "secret123", "API_KEY" => "key456" }, json)
  end

  test "fetch nested keys flattened" do
    stub_ticks.with("sops --version 2> /dev/null")
    stub_ticks
      .with("sops --decrypt --output-type json -- secrets.enc.yaml")
      .returns(<<~JSON)
        {
          "database": {
            "password": "pw",
            "host": "db.example"
          },
          "api_key": "xyz"
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "secrets.enc.yaml", "database/password", "api_key"))

    assert_equal({ "database/password" => "pw", "api_key" => "xyz" }, json)
  end

  test "fetch all when no keys given" do
    stub_ticks.with("sops --version 2> /dev/null")
    stub_ticks
      .with("sops --decrypt --output-type json -- secrets.enc.yaml")
      .returns(<<~JSON)
        {
          "database": {
            "password": "pw",
            "host": "db.example"
          },
          "api_key": "xyz"
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "secrets.enc.yaml"))

    assert_equal({
      "database/password" => "pw",
      "database/host" => "db.example",
      "api_key" => "xyz"
    }, json)
  end

  test "fetch coerces non-string values to strings" do
    stub_ticks.with("sops --version 2> /dev/null")
    stub_ticks
      .with("sops --decrypt --output-type json -- secrets.enc.json")
      .returns(<<~JSON)
        {
          "port": 5432,
          "ssl": true,
          "weight": 1.5,
          "missing": null,
          "tags": [ "prod", "db" ]
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "secrets.enc.json"))

    assert_equal({
      "port" => "5432",
      "ssl" => "true",
      "weight" => "1.5",
      "missing" => "null",
      "tags" => '["prod","db"]'
    }, json)
  end

  test "fetch a nested subtree by parent key" do
    stub_ticks.with("sops --version 2> /dev/null")
    stub_ticks
      .with("sops --decrypt --output-type json -- secrets.enc.yaml")
      .returns(<<~JSON)
        {
          "database": {
            "password": "pw",
            "host": "db.example"
          },
          "api_key": "xyz"
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "secrets.enc.yaml", "database"))

    assert_equal({ "database/password" => "pw", "database/host" => "db.example" }, json)
  end

  test "fetch without --from" do
    stub_ticks.with("sops --version 2> /dev/null")

    error = assert_raises RuntimeError do
      run_command("fetch", "DB_PASSWORD")
    end
    assert_equal "Missing required option '--from'", error.message
  end

  test "fetch unknown key" do
    stub_ticks.with("sops --version 2> /dev/null")
    stub_ticks
      .with("sops --decrypt --output-type json -- secrets.enc.json")
      .returns(<<~JSON)
        { "DB_PASSWORD": "secret123" }
      JSON

    error = assert_raises RuntimeError do
      run_command("fetch", "--from", "secrets.enc.json", "NOPE")
    end
    assert_equal "Could not find secret NOPE in secrets.enc.json", error.message
  end

  test "fetch with decryption failure" do
    stub_ticks.with("sops --version 2> /dev/null")
    stub_ticks_with("sops --decrypt --output-type json -- secrets.enc.json", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "--from", "secrets.enc.json", "DB_PASSWORD")
    end
    assert_equal "Could not decrypt secrets.enc.json with sops", error.message
  end

  test "fetch without CLI installed" do
    stub_ticks_with("sops --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "--from", "secrets.enc.json", "DB_PASSWORD")
    end
    assert_equal "sops is not installed", error.message
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "sops" ]
      end
    end
end
