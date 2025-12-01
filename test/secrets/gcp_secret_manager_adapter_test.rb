require "test_helper"

class GcpSecretManagerAdapterTest < SecretAdapterTestCase
  test "fetch" do
    stub_gcloud_version
    stub_authenticated
    stub_mypassword

    json = JSON.parse(run_command("fetch", "mypassword"))

    expected_json = { "default/mypassword"=>"secret123" }

    assert_equal expected_json, json
  end

  test "fetch unauthenticated" do
    stub_ticks.with("gcloud --version 2> /dev/null")

    stub_mypassword
    stub_unauthenticated

    error = assert_raises RuntimeError do
      JSON.parse(run_command("fetch", "mypassword"))
    end

    assert_match(/could not login to gcloud/, error.message)
  end

  test "fetch with from" do
    stub_gcloud_version
    stub_authenticated
    stub_items(0, project: "other-project")
    stub_items(1, project: "other-project")
    stub_items(2, project: "other-project")

    json = JSON.parse(run_command("fetch", "--from", "other-project", "item1", "item2", "item3"))

    expected_json = {
      "other-project/item1"=>"secret1", "other-project/item2"=>"secret2", "other-project/item3"=>"secret3"
    }

    assert_equal expected_json, json
  end

  test "fetch with multiple projects" do
    stub_gcloud_version
    stub_authenticated
    stub_items(0, project: "some-project")
    stub_items(1, project: "project-confidence")
    stub_items(2, project: "manhattan-project")

    json = JSON.parse(run_command("fetch", "some-project/item1", "project-confidence/item2", "manhattan-project/item3"))

    expected_json = {
      "some-project/item1"=>"secret1", "project-confidence/item2"=>"secret2", "manhattan-project/item3"=>"secret3"
    }

    assert_equal expected_json, json
  end

  test "fetch with specific version" do
    stub_gcloud_version
    stub_authenticated
    stub_items(0, project: "some-project", version: "123")

    json = JSON.parse(run_command("fetch", "some-project/item1/123"))

    expected_json = {
      "some-project/item1"=>"secret1"
    }

    assert_equal expected_json, json
  end

  test "fetch with non-default account" do
    stub_gcloud_version
    stub_authenticated
    stub_items(0, project: "some-project", version: "123", account: "email@example.com")

    json = JSON.parse(run_command("fetch", "some-project/item1/123", account: "email@example.com"))

    expected_json = {
      "some-project/item1"=>"secret1"
    }

    assert_equal expected_json, json
  end

  test "fetch with service account impersonation" do
    stub_gcloud_version
    stub_authenticated
    stub_items(0, project: "some-project", version: "123", impersonate_service_account: "service-user@example.com")

    json = JSON.parse(run_command("fetch", "some-project/item1/123", account: "default|service-user@example.com"))

    expected_json = {
      "some-project/item1"=>"secret1"
    }

    assert_equal expected_json, json
  end

  test "fetch with delegation chain and specific user" do
    stub_gcloud_version
    stub_authenticated
    stub_items(0, project: "some-project", version: "123", account: "user@example.com", impersonate_service_account: "service-user@example.com,service-user2@example.com")

    json = JSON.parse(run_command("fetch", "some-project/item1/123", account: "user@example.com|service-user@example.com,service-user2@example.com"))

    expected_json = {
      "some-project/item1"=>"secret1"
    }

    assert_equal expected_json, json
  end

  test "fetch with non-default account and service account impersonation" do
    stub_gcloud_version
    stub_authenticated
    stub_items(0, project: "some-project", version: "123", account: "email@example.com", impersonate_service_account: "service-user@example.com")

    json = JSON.parse(run_command("fetch", "some-project/item1/123", account: "email@example.com|service-user@example.com"))

    expected_json = {
      "some-project/item1"=>"secret1"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_gcloud_version(succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(run_command("fetch", "item1"))
    end
    assert_equal "gcloud CLI is not installed", error.message
  end

  private
    def run_command(*command, account: "default")
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "gcp_secret_manager",
            "--account", account ]
      end
    end

    def stub_gcloud_version(succeed: true)
      stub_ticks_with("gcloud --version 2> /dev/null", succeed: succeed)
    end

    def stub_authenticated
      stub_ticks
        .with("gcloud auth list --format=json")
        .returns(<<~JSON)
          [
            {
              "account": "email@example.com",
              "status": "ACTIVE"
            }
          ]
        JSON
    end

    def stub_unauthenticated
      stub_ticks
        .with("gcloud auth list --format=json")
        .returns("[]")

      stub_ticks
        .with("gcloud auth login")
        .returns(<<~JSON)
          {
            "expired": false,
            "valid": true
          }
        JSON
    end

    def stub_mypassword
      stub_ticks
        .with("gcloud secrets versions access latest --secret=mypassword --format=json")
        .returns(<<~JSON)
          {
            "name": "projects/000000000/secrets/mypassword/versions/1",
            "payload": {
              "data": "c2VjcmV0MTIz",
              "dataCrc32c": "2522602764"
            }
          }
        JSON
    end

    def stub_items(n, project: nil, account: nil, version: "latest", impersonate_service_account: nil)
      payloads = [
        { data: "c2VjcmV0MQ==", checksum: 1846998209 },
        { data: "c2VjcmV0Mg==", checksum: 2101741365 },
        { data: "c2VjcmV0Mw==", checksum: 2402124854 }
      ]
      stub_ticks
        .with("gcloud secrets versions access #{version} " \
              "--secret=item#{n + 1}" \
              "#{" --project=#{project}" if project}" \
              "#{" --account=#{account}" if account}" \
              "#{" --impersonate-service-account=#{impersonate_service_account}" if impersonate_service_account} " \
              "--format=json")
        .returns(<<~JSON)
          {
            "name": "projects/000000001/secrets/item1/versions/1",
            "payload": {
              "data": "#{payloads[n][:data]}",
              "dataCrc32c": "#{payloads[n][:checksum]}"
            }
          }
        JSON
  end
end
