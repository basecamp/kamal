require "test_helper"

class AwsSsmParameterStoreAdapterTest < SecretAdapterTestCase
  test "fails when errors are present" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws ssm get-parameters --names unknown1 unknown2 --with-decryption --profile default --output json")
      .returns(<<~JSON)
        {
          "Parameters": [],
          "InvalidParameters": [
            "unknown1",
            "unknown2"
          ]
        }
      JSON

    error = assert_raises RuntimeError do
      JSON.parse(run_command("fetch", "unknown1", "unknown2"))
    end

    assert_equal [
      "unknown1: SSM Parameter Store can't find the specified secret.",
      "unknown2: SSM Parameter Store can't find the specified secret."
    ].join(" "), error.message
  end

  test "fetch" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws ssm get-parameters --names secret/KEY1 secret/KEY2 secret2/KEY3 --with-decryption --profile default --output json")
      .returns(<<~JSON)
        {
          "Parameters": [
            {
              "Name": "secret/KEY1",
              "Value": "VALUE1"
            },
            {
              "Name": "secret/KEY2",
              "Value": "VALUE2"
            },
            {
              "Name": "secret2/KEY3",
              "Value": "VALUE3"
            }
          ],
          "InvalidParameters": []
        }
      JSON

    json = JSON.parse(run_command("fetch", "secret/KEY1", "secret/KEY2", "secret2/KEY3"))

    expected_json = {
      "secret/KEY1"=>"VALUE1",
      "secret/KEY2"=>"VALUE2",
      "secret2/KEY3"=>"VALUE3"
    }

    assert_equal expected_json, json
  end

  test "fetch batches requests to stay within the API limit" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws ssm get-parameters --names secret1 secret2 secret3 secret4 secret5 secret6 secret7 secret8 secret9 secret10 --with-decryption --profile default --output json")
      .returns(JSON.generate({
        "Parameters" => (1..10).map { |i| { "Name" => "secret#{i}", "Value" => "VALUE#{i}" } },
        "InvalidParameters" => []
      }))
    stub_ticks
      .with("aws ssm get-parameters --names secret11 --with-decryption --profile default --output json")
      .returns(JSON.generate({
        "Parameters" => [ { "Name" => "secret11", "Value" => "VALUE11" } ],
        "InvalidParameters" => []
      }))

    json = JSON.parse(run_command("fetch", *(1..11).map { |i| "secret#{i}" }))

    expected_json = (1..11).map { |i| [ "secret#{i}", "VALUE#{i}" ] }.to_h

    assert_equal expected_json, json
  end

  test "fetch with string value" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws ssm get-parameters --names secret secret2/KEY1 --with-decryption --profile default --output json")
      .returns(<<~JSON)
        {
          "Parameters": [
            {
              "Name": "secret",
              "Value": "a-string-secret"
            },
            {
              "Name": "secret2/KEY1",
              "Value": "{\\"KEY2\\":\\"VALUE2\\"}"
            }
          ],
          "InvalidParameters": []
        }
      JSON

    json = JSON.parse(run_command("fetch", "secret", "secret2/KEY1"))

    expected_json = {
      "secret"=>"a-string-secret",
      "secret2/KEY1"=>"{\"KEY2\":\"VALUE2\"}"
    }

    assert_equal expected_json, json
  end

  test "fetch with secret names" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws ssm get-parameters --names secret/KEY1 secret/KEY2 --with-decryption --profile default --output json")
      .returns(<<~JSON)
        {
          "Parameters": [
            {
              "Name": "secret/KEY1",
              "Value": "VALUE1"
            },
            {
              "Name": "secret/KEY2",
              "Value": "VALUE2"
            }
          ],
          "InvalidParameters": []
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "secret", "KEY1", "KEY2"))

    expected_json = {
      "secret/KEY1"=>"VALUE1",
      "secret/KEY2"=>"VALUE2"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_ticks_with("aws --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(run_command("fetch", "SECRET1"))
    end
    assert_equal "AWS CLI is not installed", error.message
  end

  test "fetch without account option omits --profile" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws ssm get-parameters --names secret/KEY1 secret/KEY2 --with-decryption --output json")
      .returns(<<~JSON)
        {
          "Parameters": [
            {
              "Name": "secret/KEY1",
              "Value": "VALUE1"
            },
            {
              "Name": "secret/KEY2",
              "Value": "VALUE2"
            }
          ],
          "InvalidParameters": []
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "secret", "KEY1", "KEY2", account: nil))

    expected_json = {
      "secret/KEY1"=>"VALUE1",
      "secret/KEY2"=>"VALUE2"
    }

    assert_equal expected_json, json
  end

  private
    def run_command(*command, account: "default")
      stdouted do
        args = [ *command,
                "-c", "test/fixtures/deploy_with_accessories.yml",
                "--adapter", "aws_ssm_parameter_store" ]
        args += [ "--account", account ] if account
        Kamal::Cli::Secrets.start(args)
      end
    end
end
