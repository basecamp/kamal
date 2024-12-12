require "test_helper"

class AwsSecretsManagerAdapterTest < SecretAdapterTestCase
  test "fails when errors are present" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws secretsmanager batch-get-secret-value --secret-id-list unknown1 unknown2 --profile default")
      .returns(<<~JSON)
        {
          "SecretValues": [],
          "Errors": [
            {
                "SecretId": "unknown1",
                "ErrorCode": "ResourceNotFoundException",
                "Message": "Secrets Manager can't find the specified secret."
            },
            {
                "SecretId": "unknown2",
                "ErrorCode": "ResourceNotFoundException",
                "Message": "Secrets Manager can't find the specified secret."
            }
          ]
        }
      JSON

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "unknown1", "unknown2")))
    end

    assert_equal [ "unknown1: Secrets Manager can't find the specified secret.", "unknown2: Secrets Manager can't find the specified secret." ].join(" "), error.message
  end

  test "fetch" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws secretsmanager batch-get-secret-value --secret-id-list secret/KEY1 secret/KEY2 secret2/KEY3 --profile default")
      .returns(<<~JSON)
        {
          "SecretValues": [
            {
              "ARN": "arn:aws:secretsmanager:us-east-1:aaaaaaaaaaaa:secret:secret",
              "Name": "secret",
              "VersionId": "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv",
              "SecretString": "{\\"KEY1\\":\\"VALUE1\\", \\"KEY2\\":\\"VALUE2\\"}",
              "VersionStages": [
                  "AWSCURRENT"
              ],
              "CreatedDate": "2024-01-01T00:00:00.000000"
            },
            {
              "ARN": "arn:aws:secretsmanager:us-east-1:aaaaaaaaaaaa:secret:secret2",
              "Name": "secret2",
              "VersionId": "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv",
              "SecretString": "{\\"KEY3\\":\\"VALUE3\\"}",
              "VersionStages": [
                  "AWSCURRENT"
              ],
              "CreatedDate": "2024-01-01T00:00:00.000000"
            }
          ],
          "Errors": []
        }
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "secret/KEY1", "secret/KEY2", "secret2/KEY3")))

    expected_json = {
      "secret/KEY1"=>"VALUE1",
      "secret/KEY2"=>"VALUE2",
      "secret2/KEY3"=>"VALUE3"
    }

    assert_equal expected_json, json
  end

  test "fetch with string value" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws secretsmanager batch-get-secret-value --secret-id-list secret secret2/KEY1 --profile default")
      .returns(<<~JSON)
        {
          "SecretValues": [
            {
              "ARN": "arn:aws:secretsmanager:us-east-1:aaaaaaaaaaaa:secret:secret",
              "Name": "secret",
              "VersionId": "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv",
              "SecretString": "a-string-secret",
              "VersionStages": [
                  "AWSCURRENT"
              ],
              "CreatedDate": "2024-01-01T00:00:00.000000"
            },
            {
              "ARN": "arn:aws:secretsmanager:us-east-1:aaaaaaaaaaaa:secret:secret2",
              "Name": "secret2",
              "VersionId": "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv",
              "SecretString": "{\\"KEY2\\":\\"VALUE2\\"}",
              "VersionStages": [
                  "AWSCURRENT"
              ],
              "CreatedDate": "2024-01-01T00:00:00.000000"
            }
          ],
          "Errors": []
        }
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "secret", "secret2/KEY1")))

    expected_json = {
      "secret"=>"a-string-secret",
      "secret2/KEY2"=>"VALUE2"
    }

    assert_equal expected_json, json
  end

  test "fetch with secret names" do
    stub_ticks.with("aws --version 2> /dev/null")
    stub_ticks
      .with("aws secretsmanager batch-get-secret-value --secret-id-list secret/KEY1 secret/KEY2 --profile default")
      .returns(<<~JSON)
        {
          "SecretValues": [
            {
              "ARN": "arn:aws:secretsmanager:us-east-1:aaaaaaaaaaaa:secret:secret",
              "Name": "secret",
              "VersionId": "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv",
              "SecretString": "{\\"KEY1\\":\\"VALUE1\\", \\"KEY2\\":\\"VALUE2\\"}",
              "VersionStages": [
                  "AWSCURRENT"
              ],
              "CreatedDate": "2024-01-01T00:00:00.000000"
            }
          ],
          "Errors": []
        }
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "secret", "KEY1", "KEY2")))

    expected_json = {
      "secret/KEY1"=>"VALUE1",
      "secret/KEY2"=>"VALUE2"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_ticks_with("aws --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "SECRET1")))
    end
    assert_equal "AWS CLI is not installed", error.message
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "aws_secrets_manager",
            "--account", "default" ]
      end
    end
end
