require "test_helper"

class PassboltAdapterTest < SecretAdapterTestCase
  setup do
    `true` # Ensure $? is 0
  end

  test "fetch" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: true)
    stub_ticks.with("passbolt verify 2> /dev/null", succeed: true)

    stub_ticks
      .with("passbolt list resources --filter 'Name == \"SECRET1\" || Name == \"FSECRET1\" || Name == \"FSECRET2\"'  --json")
      .returns(<<~JSON)
        [
          {
            "id": "4c116996-f6d0-4342-9572-0d676f75b3ac",
            "folder_parent_id": "",
            "name": "FSECRET1",
            "username": "",
            "uri": "",
            "password": "fsecret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:29Z",
            "modified_timestamp": "2025-02-21T06:04:29Z"
          },
          {
            "id": "62949b26-4957-43fe-9523-294d66861499",
            "folder_parent_id": "",
            "name": "FSECRET2",
            "username": "",
            "uri": "",
            "password": "fsecret2",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:34Z",
            "modified_timestamp": "2025-02-21T06:04:34Z"
          },
          {
            "id": "dd32963c-0db5-4303-a6fc-22c5229dabef",
            "folder_parent_id": "",
            "name": "SECRET1",
            "username": "",
            "uri": "",
            "password": "secret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:23Z",
            "modified_timestamp": "2025-02-21T06:04:23Z"
          }
        ]
      JSON

    json = JSON.parse(
      shellunescape run_command("fetch", "SECRET1", "FSECRET1", "FSECRET2")
    )

    expected_json = {
      "SECRET1"=>"secret1",
      "FSECRET1"=>"fsecret1",
      "FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch with --from" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: true)
    stub_ticks.with("passbolt verify 2> /dev/null", succeed: true)

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"my-project\"' --json")
      .returns(folder_my_project_json)

    stub_ticks
      .with("passbolt list resources --filter 'Name == \"SECRET1\" || Name == \"FSECRET1\" || Name == \"FSECRET2\"' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --json")
      .returns(<<~JSON)
        [
          {
            "id": "4c116996-f6d0-4342-9572-0d676f75b3ac",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "FSECRET1",
            "username": "",
            "uri": "",
            "password": "fsecret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:29Z",
            "modified_timestamp": "2025-02-21T06:04:29Z"
          },
          {
            "id": "62949b26-4957-43fe-9523-294d66861499",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "FSECRET2",
            "username": "",
            "uri": "",
            "password": "fsecret2",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:34Z",
            "modified_timestamp": "2025-02-21T06:04:34Z"
          },
          {
            "id": "dd32963c-0db5-4303-a6fc-22c5229dabef",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "SECRET1",
            "username": "",
            "uri": "",
            "password": "secret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:23Z",
            "modified_timestamp": "2025-02-21T06:04:23Z"
          }
        ]
      JSON

    json = JSON.parse(
      shellunescape run_command("fetch", "--from", "my-project", "SECRET1", "FSECRET1", "FSECRET2")
    )

    expected_json = {
      "SECRET1"=>"secret1",
      "FSECRET1"=>"fsecret1",
      "FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch with folder in secret" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: true)
    stub_ticks.with("passbolt verify 2> /dev/null", succeed: true)

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"my-project\"' --json")
      .returns(folder_my_project_json)

    stub_ticks
      .with("passbolt list resources --filter 'Name == \"SECRET1\" || Name == \"FSECRET1\" || Name == \"FSECRET2\"' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --json")
      .returns(<<~JSON)
        [
          {
            "id": "4c116996-f6d0-4342-9572-0d676f75b3ac",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "FSECRET1",
            "username": "",
            "uri": "",
            "password": "fsecret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:29Z",
            "modified_timestamp": "2025-02-21T06:04:29Z"
          },
          {
            "id": "62949b26-4957-43fe-9523-294d66861499",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "FSECRET2",
            "username": "",
            "uri": "",
            "password": "fsecret2",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:34Z",
            "modified_timestamp": "2025-02-21T06:04:34Z"
          },
          {
            "id": "dd32963c-0db5-4303-a6fc-22c5229dabef",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "SECRET1",
            "username": "",
            "uri": "",
            "password": "secret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:23Z",
            "modified_timestamp": "2025-02-21T06:04:23Z"
          }
        ]
      JSON

    json = JSON.parse(
      shellunescape run_command("fetch", "my-project/SECRET1", "my-project/FSECRET1", "my-project/FSECRET2")
    )

    expected_json = {
      "SECRET1"=>"secret1",
      "FSECRET1"=>"fsecret1",
      "FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch from multiple folders" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: true)
    stub_ticks.with("passbolt verify 2> /dev/null", succeed: true)

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"my-project\"' --json")
      .returns(folder_my_project_json)

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"other-project\"' --json")
      .returns(folder_other_project_json)

    stub_ticks
      .with("passbolt list resources --filter 'Name == \"SECRET1\" || Name == \"FSECRET1\" || Name == \"FSECRET2\"' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --folder 14e11dd8-b279-4689-8bd9-fa33ebb527da --json")
      .returns(<<~JSON)
        [
          {
            "id": "4c116996-f6d0-4342-9572-0d676f75b3ac",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "FSECRET1",
            "username": "",
            "uri": "",
            "password": "fsecret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:29Z",
            "modified_timestamp": "2025-02-21T06:04:29Z"
          },
          {
            "id": "62949b26-4957-43fe-9523-294d66861499",
            "folder_parent_id": "14e11dd8-b279-4689-8bd9-fa33ebb527da",
            "name": "FSECRET2",
            "username": "",
            "uri": "",
            "password": "fsecret2",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:34Z",
            "modified_timestamp": "2025-02-21T06:04:34Z"
          },
          {
            "id": "dd32963c-0db5-4303-a6fc-22c5229dabef",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "SECRET1",
            "username": "",
            "uri": "",
            "password": "secret1",
            "description": "",
            "created_timestamp": "2025-02-21T06:04:23Z",
            "modified_timestamp": "2025-02-21T06:04:23Z"
          }
        ]
      JSON

    json = JSON.parse(
      shellunescape run_command("fetch", "my-project/SECRET1", "my-project/FSECRET1", "other-project/FSECRET2")
    )

    expected_json = {
      "SECRET1"=>"secret1",
      "FSECRET1"=>"fsecret1",
      "FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "HOST", "PORT")))
    end

    assert_equal "Passbolt CLI is not installed", error.message
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "passbolt" ]
      end
    end

    def folder_my_project_json
      <<~JSON
        [
          {
            "id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "my-project"
          }
        ]
      JSON
    end

    def folder_other_project_json
      <<~JSON
        [
          {
            "id": "14e11dd8-b279-4689-8bd9-fa33ebb527da",
            "name": "other-project"
          }
        ]
      JSON
    end
end