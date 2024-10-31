require "test_helper"

class DopplerAdapterTest < SecretAdapterTestCase
  setup do
    ENV.delete("DOPPLER_TOKEN")
    `true` # Ensure $? is 0
  end

  test "fetch" do
    ENV["DOPPLER_TOKEN"] = "dp.st.xxxxxxxxxxxxxxxxxxxxxx"
    stub_ticks.with("doppler --version 2> /dev/null")
    stub_ticks.with("doppler me 2> /dev/null")

    stub_ticks
      .with("doppler secrets get --json HOST PORT")
      .returns(secrets_get_json)

    json = JSON.parse(shellunescape(run_command("fetch", "HOST", "PORT")))

    expected_json = {
      "HOST"=>"0.0.0.0",
      "PORT"=>"8080"
    }

    assert_equal expected_json, json
    ENV.delete("DOPPLER_TOKEN")
  end

  test "fetch with from" do
    stub_ticks.with("doppler --version 2> /dev/null")
    stub_ticks.with("doppler me 2> /dev/null")

    stub_ticks
      .with("doppler secrets get --json -p example -c dev HOST PORT")
      .returns(secrets_get_json)

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "example/dev", "HOST", "PORT")))

    expected_json = {
      "HOST"=>"0.0.0.0",
      "PORT"=>"8080"
    }

    assert_equal expected_json, json
  end

  test "fetch all" do
    ENV["DOPPLER_TOKEN"] = "dp.st.xxxxxxxxxxxxxxxxxxxxxx"
    stub_ticks.with("doppler --version 2> /dev/null")
    stub_ticks.with("doppler me 2> /dev/null")

    stub_ticks
      .with("doppler secrets download --no-file --json")
      .returns(secrets_download_json)

    json = JSON.parse(shellunescape(run_command("fetch", "all")))

    expected_json = {
      "DOPPLER_PROJECT"=>"example",
      "DOPPLER_ENVIRONMENT"=>"dev",
      "DOPPLER_CONFIG"=>"dev",
      "HOST"=>"0.0.0.0",
      "PORT"=>"8080"
    }

    assert_equal expected_json, json
    ENV.delete("DOPPLER_TOKEN")
  end

  test "fetch all with from" do
    stub_ticks.with("doppler --version 2> /dev/null")
    stub_ticks.with("doppler me 2> /dev/null")

    stub_ticks
      .with("doppler secrets download --no-file --json -p example -c dev")
      .returns(secrets_download_json)

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "example/dev", "all")))

    expected_json = {
      "DOPPLER_PROJECT"=>"example",
      "DOPPLER_ENVIRONMENT"=>"dev",
      "DOPPLER_CONFIG"=>"dev",
      "HOST"=>"0.0.0.0",
      "PORT"=>"8080"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_ticks_with("doppler --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "HOST", "PORT")))
    end
    assert_equal "Doppler CLI is not installed", error.message
  end

  test "fetch without being logged in and without DOPPLER_TOKEN" do
    stub_ticks_with("doppler --version 2> /dev/null")
    stub_ticks_with("doppler me 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "HOST", "PORT")))
    end
    assert_equal "Doppler CLI not logged in and no DOPPLER_TOKEN found in environment", error.message
  end

  test "fetch with from and no secrets or 'all' specified" do
    stub_ticks.with("doppler --version 2> /dev/null")
    stub_ticks.with("doppler me 2> /dev/null")

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "--from", "example/dev")))
    end
    assert_equal "No secrets were fetched. Please specify which secrets to fetch or use 'all' to fetch all secrets.", error.message
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "doppler",
            "--account", "-" ]
      end
    end

    def secrets_get_json
      <<~JSON
        {
          "HOST": {
            "computed": "0.0.0.0",
            "computedValueType": {
              "type": "string"
            },
            "computedVisibility": "masked",
            "note": ""
          },
          "PORT": {
            "computed": "8080",
            "computedValueType": {
              "type": "string"
            },
            "computedVisibility": "masked",
            "note": ""
          }
        }
      JSON
    end

    def secrets_download_json
      <<~JSON
        {
          "DOPPLER_CONFIG": "dev",
          "DOPPLER_ENVIRONMENT": "dev",
          "DOPPLER_PROJECT": "example",
          "HOST": "0.0.0.0",
          "PORT": "8080"
        }
      JSON
    end
end
