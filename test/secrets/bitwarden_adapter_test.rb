require "test_helper"

class BitwardenAdapterTest < SecretAdapterTestCase
  test "fetch" do
    stub_unlocked
    stub_ticks.with("bw sync").returns("")
    stub_mypassword

    json = JSON.parse(shellunescape(run_command("fetch", "mypassword")))

    expected_json = { "mypassword"=>"secret123" }

    assert_equal expected_json, json
  end

  test "fetch with from" do
    stub_unlocked
    stub_ticks.with("bw sync").returns("")
    stub_myitem

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "myitem", "field1", "field2", "field3")))

    expected_json = {
      "myitem/field1"=>"secret1", "myitem/field2"=>"blam", "myitem/field3"=>"fewgrwjgk"
    }

    assert_equal expected_json, json
  end

  test "fetch with multiple items" do
    stub_unlocked

    stub_ticks.with("bw sync").returns("")
    stub_mypassword
    stub_myitem

    stub_ticks
    .with("bw get item myitem2")
    .returns(<<~JSON)
      {
        "passwordHistory":null,
        "revisionDate":"2024-08-29T13:46:53.343Z",
        "creationDate":"2024-08-29T12:02:31.156Z",
        "deletedDate":null,
        "object":"item",
        "id":"aaaaaaaa-cccc-eeee-0000-222222222222",
        "organizationId":null,
        "folderId":null,
        "type":1,
        "reprompt":0,
        "name":"myitem2",
        "notes":null,
        "favorite":false,
        "fields":[
          {"name":"field3","value":"fewgrwjgk","type":1,"linkedId":null}
        ],
        "login":{"fido2Credentials":[],"uris":[],"username":null,"password":null,"totp":null,"passwordRevisionDate":null},"collectionIds":[]
      }
    JSON


    json = JSON.parse(shellunescape(run_command("fetch", "mypassword", "myitem/field1", "myitem/field2", "myitem2/field3")))

    expected_json = {
      "mypassword"=>"secret123", "myitem/field1"=>"secret1", "myitem/field2"=>"blam", "myitem2/field3"=>"fewgrwjgk"
    }

    assert_equal expected_json, json
  end

  test "fetch unauthenticated" do
    stub_ticks
      .with("bw status")
      .returns(
        '{"serverUrl":null,"lastSync":null,"status":"unauthenticated"}',
        '{"serverUrl":null,"lastSync":"2024-09-04T10:11:12.433Z","userEmail":"email@example.com","userId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","status":"locked"}',
        '{"serverUrl":null,"lastSync":"2024-09-04T10:11:12.433Z","userEmail":"email@example.com","userId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","status":"unlocked"}'
      )

    stub_ticks.with("bw login email@example.com").returns("1234567890")
    stub_ticks.with("bw unlock --raw").returns("")
    stub_ticks.with("bw sync").returns("")
    stub_mypassword

    json = JSON.parse(shellunescape(run_command("fetch", "mypassword")))

    expected_json = { "mypassword"=>"secret123" }

    assert_equal expected_json, json
  end

  test "fetch locked" do
    stub_ticks
      .with("bw status")
      .returns(
        '{"serverUrl":null,"lastSync":"2024-09-04T10:11:12.433Z","userEmail":"email@example.com","userId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","status":"locked"}'
      )

    stub_ticks
      .with("bw status")
      .returns(
        '{"serverUrl":null,"lastSync":"2024-09-04T10:11:12.433Z","userEmail":"email@example.com","userId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","status":"unlocked"}'
      )

    stub_ticks.with("bw login email@example.com").returns("1234567890")
    stub_ticks.with("bw unlock --raw").returns("")
    stub_ticks.with("bw sync").returns("")
    stub_mypassword

    json = JSON.parse(shellunescape(run_command("fetch", "mypassword")))

    expected_json = { "mypassword"=>"secret123" }

    assert_equal expected_json, json
  end

  test "fetch locked with session" do
    stub_ticks
      .with("bw status")
      .returns(
        '{"serverUrl":null,"lastSync":"2024-09-04T10:11:12.433Z","userEmail":"email@example.com","userId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","status":"locked"}'
      )

    stub_ticks
      .with("BW_SESSION=0987654321 bw status")
      .returns(
        '{"serverUrl":null,"lastSync":"2024-09-04T10:11:12.433Z","userEmail":"email@example.com","userId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","status":"unlocked"}'
      )

    stub_ticks.with("bw login email@example.com").returns("1234567890")
    stub_ticks.with("bw unlock --raw").returns("0987654321")
    stub_ticks.with("BW_SESSION=0987654321 bw sync").returns("")
    stub_mypassword(session: "0987654321")

    json = JSON.parse(shellunescape(run_command("fetch", "mypassword")))

    expected_json = { "mypassword"=>"secret123" }

    assert_equal expected_json, json
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "bitwarden",
            "--account", "email@example.com" ]
      end
    end

    def stub_unlocked
      stub_ticks
        .with("bw status")
        .returns(<<~JSON)
          {"serverUrl":null,"lastSync":"2024-09-04T10:11:12.433Z","userEmail":"email@example.com","userId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","status":"unlocked"}
        JSON
    end

    def stub_mypassword(session: nil)
      stub_ticks
        .with("#{"BW_SESSION=#{session} " if session}bw get item mypassword")
        .returns(<<~JSON)
          {
            "passwordHistory":null,
            "revisionDate":"2024-08-29T13:46:53.343Z",
            "creationDate":"2024-08-29T12:02:31.156Z",
            "deletedDate":null,
            "object":"item",
            "id":"aaaaaaaa-cccc-eeee-0000-222222222222",
            "organizationId":null,
            "folderId":null,
            "type":1,
            "reprompt":0,
            "name":"mypassword",
            "notes":null,
            "favorite":false,
            "login":{"fido2Credentials":[],"uris":[],"username":null,"password":"secret123","totp":null,"passwordRevisionDate":null},"collectionIds":[]
          }
        JSON
    end

    def stub_myitem
      stub_ticks
        .with("bw get item myitem")
        .returns(<<~JSON)
          {
            "passwordHistory":null,
            "revisionDate":"2024-08-29T13:46:53.343Z",
            "creationDate":"2024-08-29T12:02:31.156Z",
            "deletedDate":null,
            "object":"item",
            "id":"aaaaaaaa-cccc-eeee-0000-222222222222",
            "organizationId":null,
            "folderId":null,
            "type":1,
            "reprompt":0,
            "name":"myitem",
            "notes":null,
            "favorite":false,
            "fields":[
              {"name":"field1","value":"secret1","type":1,"linkedId":null},
              {"name":"field2","value":"blam","type":1,"linkedId":null},
              {"name":"field3","value":"fewgrwjgk","type":1,"linkedId":null}
            ],
            "login":{"fido2Credentials":[],"uris":[],"username":null,"password":null,"totp":null,"passwordRevisionDate":null},"collectionIds":[]
          }
        JSON
    end
end
