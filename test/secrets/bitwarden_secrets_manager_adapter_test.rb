require "test_helper"

class BitwardenSecretsManagerAdapterTest < SecretAdapterTestCase
  test "fetch with no parameters" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login

    error = assert_raises RuntimeError do
      run_command("fetch")
    end
    assert_equal("You must specify what to retrieve from Bitwarden Secrets Manager", error.message)
  end

  test "fetch all" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login
    stub_ticks
      .with("bws secret list")
      .returns(<<~JSON)
      [
        {
          "key": "KAMAL_REGISTRY_PASSWORD",
          "value": "some_password"
        },
        {
          "key": "MY_OTHER_SECRET",
          "value": "my=wierd\\"secret"
        }
      ]
      JSON

    json = JSON.parse(run_command("fetch", "all"))

    expected_json = {
      "KAMAL_REGISTRY_PASSWORD"=>"some_password",
      "MY_OTHER_SECRET"=>"my=wierd\"secret"
    }

    assert_equal expected_json, json
  end

  test "fetch all with from" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login
    stub_ticks
      .with("bws secret list 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns(<<~JSON)
      [
        {
          "key": "KAMAL_REGISTRY_PASSWORD",
          "value": "some_password"
        },
        {
          "key": "MY_OTHER_SECRET",
          "value": "my=wierd\\"secret"
        }
      ]
      JSON

    json = JSON.parse(run_command("fetch", "all", "--from", "82aeb5bd-6958-4a89-8197-eacab758acce"))

    expected_json = {
      "KAMAL_REGISTRY_PASSWORD"=>"some_password",
      "MY_OTHER_SECRET"=>"my=wierd\"secret"
    }

    assert_equal expected_json, json
  end

  test "fetch item" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login
    stub_ticks
      .with("bws secret get 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns(<<~JSON)
      {
        "key": "KAMAL_REGISTRY_PASSWORD",
        "value": "some_password"
      }
      JSON

    json = JSON.parse(run_command("fetch", "82aeb5bd-6958-4a89-8197-eacab758acce"))
    expected_json = {
      "KAMAL_REGISTRY_PASSWORD"=>"some_password"
    }

    assert_equal expected_json, json
  end

  test "fetch with multiple items" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login
    stub_ticks
      .with("bws secret get 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns(<<~JSON)
      {
        "key": "KAMAL_REGISTRY_PASSWORD",
        "value": "some_password"
      }
      JSON
    stub_ticks
      .with("bws secret get 6f8cdf27-de2b-4c77-a35d-07df8050e332")
      .returns(<<~JSON)
      {
        "key": "MY_OTHER_SECRET",
        "value": "my=wierd\\"secret"
      }
      JSON

    json = JSON.parse(run_command("fetch", "82aeb5bd-6958-4a89-8197-eacab758acce", "6f8cdf27-de2b-4c77-a35d-07df8050e332"))
    expected_json = {
      "KAMAL_REGISTRY_PASSWORD"=>"some_password",
      "MY_OTHER_SECRET"=>"my=wierd\"secret"
    }

    assert_equal expected_json, json
  end

  test "fetch all empty" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login
    stub_ticks_with("bws secret list", succeed: false).returns("Error:\n0: Received error message from server")

    error = assert_raises RuntimeError do
      (run_command("fetch", "all"))
    end
    assert_equal("Could not read secrets from Bitwarden Secrets Manager", error.message)
  end

  test "fetch nonexistent item" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login
    stub_ticks_with("bws secret get 82aeb5bd-6958-4a89-8197-eacab758acce", succeed: false)
      .returns("Error:\n0: Received error message from server")

    error = assert_raises RuntimeError do
      (run_command("fetch", "82aeb5bd-6958-4a89-8197-eacab758acce"))
    end
    assert_equal("Could not read 82aeb5bd-6958-4a89-8197-eacab758acce from Bitwarden Secrets Manager", error.message)
  end

  test "fetch item with linebreak in value" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_login
    stub_ticks
      .with("bws secret get 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns(<<~JSON)
      {
        "key": "SSH_PRIVATE_KEY",
        "value": "some_key\\nwith_linebreak"
      }
      JSON

    json = JSON.parse(run_command("fetch", "82aeb5bd-6958-4a89-8197-eacab758acce"))
    expected_json = {
      "SSH_PRIVATE_KEY"=>"some_key\nwith_linebreak"
    }

    assert_equal expected_json, json
  end

  test "fetch with no access token" do
    stub_ticks.with("bws --version 2> /dev/null")
    stub_ticks_with("bws project list", succeed: false)

    error = assert_raises RuntimeError do
      (run_command("fetch", "all"))
    end
    assert_equal("Could not authenticate to Bitwarden Secrets Manager. Did you set a valid access token?", error.message)
  end

  test "fetch without CLI installed" do
    stub_ticks_with("bws --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch")
    end
    assert_equal "Bitwarden Secrets Manager CLI is not installed", error.message
  end

  private
    def stub_login
      stub_ticks.with("bws project list").returns("OK")
    end

    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "--adapter", "bitwarden-sm" ]
      end
    end
end
