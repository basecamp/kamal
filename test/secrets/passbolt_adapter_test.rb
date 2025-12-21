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
      run_command("fetch", "SECRET1", "FSECRET1", "FSECRET2")
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
      .returns(<<~JSON)
        [
          {
            "id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "folder_parent_id": "",
            "name": "my-project",
            "created_timestamp": "2025-02-21T19:52:50Z",
            "modified_timestamp": "2025-02-21T19:52:50Z"
          }
        ]
      JSON

    stub_ticks
      .with("passbolt list resources --filter '(Name == \"SECRET1\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\") || (Name == \"FSECRET1\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\") || (Name == \"FSECRET2\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\")' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --json")
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
      run_command("fetch", "--from", "my-project", "SECRET1", "FSECRET1", "FSECRET2")
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
      .returns(<<~JSON)
        [
          {
            "id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "folder_parent_id": "",
            "name": "my-project",
            "created_timestamp": "2025-02-21T19:52:50Z",
            "modified_timestamp": "2025-02-21T19:52:50Z"
          }
        ]
      JSON

    stub_ticks
      .with("passbolt list resources --filter '(Name == \"SECRET1\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\") || (Name == \"FSECRET1\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\") || (Name == \"FSECRET2\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\")' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --json")
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
      run_command("fetch", "my-project/SECRET1", "my-project/FSECRET1", "my-project/FSECRET2")
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
      .with("passbolt list folders --filter 'Name == \"my-project\" || Name == \"other-project\"' --json")
      .returns(<<~JSON)
        [
          {
            "id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "folder_parent_id": "",
            "name": "my-project",
            "created_timestamp": "2025-02-21T19:52:50Z",
            "modified_timestamp": "2025-02-21T19:52:50Z"
          },
          {
            "id": "14e11dd8-b279-4689-8bd9-fa33ebb527da",
            "folder_parent_id": "",
            "name": "other-project",
            "created_timestamp": "2025-02-21T20:00:29Z",
            "modified_timestamp": "2025-02-21T20:00:29Z"
          }
        ]
      JSON

    stub_ticks
      .with("passbolt list resources --filter '(Name == \"SECRET1\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\") || (Name == \"FSECRET1\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\") || (Name == \"FSECRET2\" && FolderParentID == \"14e11dd8-b279-4689-8bd9-fa33ebb527da\")' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --folder 14e11dd8-b279-4689-8bd9-fa33ebb527da --json")
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
      run_command("fetch", "my-project/SECRET1", "my-project/FSECRET1", "other-project/FSECRET2")
    )

    expected_json = {
      "SECRET1"=>"secret1",
      "FSECRET1"=>"fsecret1",
      "FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch from nested folder" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: true)
    stub_ticks.with("passbolt verify 2> /dev/null", succeed: true)

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"my-project\"' --json")
      .returns(<<~JSON)
        [
          {
            "id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "folder_parent_id": "",
            "name": "my-project",
            "created_timestamp": "2025-02-21T19:52:50Z",
            "modified_timestamp": "2025-02-21T19:52:50Z"
          }
        ]
      JSON

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"subfolder\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\"' --json")
      .returns(<<~JSON)
        [
          {
            "id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "subfolder",
            "created_timestamp": "2025-02-21T19:52:50Z",
            "modified_timestamp": "2025-02-21T19:52:50Z"
          }
        ]
      JSON

    stub_ticks
      .with("passbolt list resources --filter '(Name == \"SECRET1\" && FolderParentID == \"6a3f21fc-aa40-4ba9-852c-7477fdd0310d\") || (Name == \"FSECRET1\" && FolderParentID == \"6a3f21fc-aa40-4ba9-852c-7477fdd0310d\") || (Name == \"FSECRET2\" && FolderParentID == \"6a3f21fc-aa40-4ba9-852c-7477fdd0310d\")' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --folder 6a3f21fc-aa40-4ba9-852c-7477fdd0310d --json")
      .returns(<<~JSON)
        [
          {
            "id": "4c116996-f6d0-4342-9572-0d676f75b3ac",
            "folder_parent_id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
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
            "folder_parent_id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
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
            "folder_parent_id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
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
      run_command("fetch", "--from", "my-project/subfolder", "SECRET1", "FSECRET1", "FSECRET2")
    )

    expected_json = {
      "SECRET1"=>"secret1",
      "FSECRET1"=>"fsecret1",
      "FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch from nested folder in secret" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: true)
    stub_ticks.with("passbolt verify 2> /dev/null", succeed: true)

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"my-project\"' --json")
      .returns(<<~JSON)
        [
          {
            "id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "folder_parent_id": "",
            "name": "my-project",
            "created_timestamp": "2025-02-21T19:52:50Z",
            "modified_timestamp": "2025-02-21T19:52:50Z"
          }
        ]
      JSON

    stub_ticks
      .with("passbolt list folders --filter 'Name == \"subfolder\" && FolderParentID == \"dcbe0e39-42d8-42db-9637-8256b9f2f8e3\"' --json")
      .returns(<<~JSON)
        [
          {
            "id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
            "folder_parent_id": "dcbe0e39-42d8-42db-9637-8256b9f2f8e3",
            "name": "subfolder",
            "created_timestamp": "2025-02-21T19:52:50Z",
            "modified_timestamp": "2025-02-21T19:52:50Z"
          }
        ]
      JSON

    stub_ticks
      .with("passbolt list resources --filter '(Name == \"SECRET1\" && FolderParentID == \"6a3f21fc-aa40-4ba9-852c-7477fdd0310d\") || (Name == \"FSECRET1\" && FolderParentID == \"6a3f21fc-aa40-4ba9-852c-7477fdd0310d\") || (Name == \"FSECRET2\" && FolderParentID == \"6a3f21fc-aa40-4ba9-852c-7477fdd0310d\")' --folder dcbe0e39-42d8-42db-9637-8256b9f2f8e3 --folder 6a3f21fc-aa40-4ba9-852c-7477fdd0310d --json")
      .returns(<<~JSON)
        [
          {
            "id": "4c116996-f6d0-4342-9572-0d676f75b3ac",
            "folder_parent_id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
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
            "folder_parent_id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
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
            "folder_parent_id": "6a3f21fc-aa40-4ba9-852c-7477fdd0310d",
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
      run_command("fetch", "my-project/subfolder/SECRET1", "my-project/subfolder/FSECRET1", "my-project/subfolder/FSECRET2")
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
      JSON.parse(run_command("fetch", "HOST", "PORT"))
    end

    assert_equal "Passbolt CLI is not installed", error.message
  end

  test "fetch with special characters in folder id" do
    stub_ticks_with("passbolt --version 2> /dev/null", succeed: true)
    stub_ticks_with("passbolt verify", succeed: true)

    stub_ticks.with("passbolt list folders --filter 'Name == \"my-project\"' --json")
      .returns('[{"id":"abc def-123","folder_parent_id":"","name":"my-project","created_timestamp":"2025-02-21T19:52:50Z","modified_timestamp":"2025-02-21T19:52:50Z"}]')

    stub_ticks.with("passbolt list resources --filter '(Name == \"SECRET1\" && FolderParentID == \"abc\\\\ def-123\")' --folder abc\\ def-123 --json")
      .returns('[{"id":"dd32963c","folder_parent_id":"abc def-123","name":"SECRET1","username":"","uri":"","password":"secret1","description":"","created_timestamp":"2025-02-21T06:04:23Z","modified_timestamp":"2025-02-21T06:04:23Z"}]')

    json = JSON.parse(run_command("fetch", "my-project/SECRET1"))

    assert_equal({ "SECRET1"=>"secret1" }, json)
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
end
