require "test_helper"

class SecretsOnePasswordAdapterTest < SecretAdapterTestCase
  test "fetch" do
    stub_ticks.with("op --version 2> /dev/null")
    stub_ticks.with("op account get --account myaccount 2> /dev/null")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --format \"json\" --account \"myaccount\"")
      .returns(full_item_json)

    json = JSON.parse(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1", "section/SECRET2", "section2/SECRET3"))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1",
      "myvault/myitem/section/SECRET2"=>"VALUE2",
      "myvault/myitem/section2/SECRET3"=>"VALUE3"
    }

    assert_equal expected_json, json
  end

  test "fetch with multiple items" do
    stub_ticks.with("op --version 2> /dev/null")
    stub_ticks.with("op account get --account myaccount 2> /dev/null")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --format \"json\" --account \"myaccount\"")
      .returns(full_item_json)

    stub_ticks
      .with("op item get myitem2 --vault \"myvault\" --format \"json\" --account \"myaccount\"")
      .returns(full_item2_json)

    json = JSON.parse(run_command("fetch", "--from", "op://myvault", "myitem/section/SECRET1", "myitem/section/SECRET2", "myitem2/section2/SECRET3"))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1",
      "myvault/myitem/section/SECRET2"=>"VALUE2",
      "myvault/myitem2/section2/SECRET3"=>"VALUE3"
    }

    assert_equal expected_json, json
  end

  test "fetch all fields" do
    stub_ticks.with("op --version 2> /dev/null")
    stub_ticks.with("op account get --account myaccount 2> /dev/null")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --format \"json\" --account \"myaccount\"")
      .returns(<<~JSON)
        {
          "id": "ucbtiii777",
          "title": "A title",
          "version": 45,
          "vault": {
            "id": "vu7ki98do",
            "name": "Vault"
          },
          "category": "LOGIN",
          "last_edited_by": "ABCT3684BC",
          "created_at": "2025-05-22T06:47:01Z",
          "updated_at": "2025-05-22T00:36:48.02598-07:00",
          "additional_information": "—",
          "fields": [
            {
              "id": "aaaaaaaaaaaaaaaaaaaaaaaaaa",
              "section": {
                "id": "cccccccccccccccccccccccccc",
                "label": "section"
              },
              "type": "CONCEALED",
              "label": "SECRET1",
              "value": "VALUE1",
              "reference": "op://myvault/myitem/section/SECRET1"
            },
            {
              "id": "bbbbbbbbbbbbbbbbbbbbbbbbbb",
              "section": {
                "id": "cccccccccccccccccccccccccc",
                "label": "section"
              },
              "type": "CONCEALED",
              "label": "SECRET2",
              "value": "VALUE2",
              "reference": "op://myvault/myitem/section/SECRET2"
            }
          ]
        }
      JSON

    json = JSON.parse(run_command("fetch", "--from", "op://myvault/myitem"))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1",
      "myvault/myitem/section/SECRET2"=>"VALUE2"
    }

    assert_equal expected_json, json
  end

  test "fetch with signin, no session" do
    stub_ticks.with("op --version 2> /dev/null")

    stub_ticks_with("op account get --account myaccount 2> /dev/null", succeed: false)
    stub_ticks_with("op signin --account \"myaccount\" --force --raw", succeed: true).returns("")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --format \"json\" --account \"myaccount\"")
      .returns(single_field_item_json)

    json = JSON.parse(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1"))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1"
    }

    assert_equal expected_json, json
  end

  test "fetch with signin and session" do
    stub_ticks.with("op --version 2> /dev/null")

    stub_ticks_with("op account get --account myaccount 2> /dev/null", succeed: false)
    stub_ticks_with("op signin --account \"myaccount\" --force --raw", succeed: true).returns("1234567890")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --format \"json\" --account \"myaccount\" --session \"1234567890\"")
      .returns(single_field_item_json)

    json = JSON.parse(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1"))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_ticks_with("op --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1", "section/SECRET2", "section2/SECRET3"))
    end
    assert_equal "1Password CLI is not installed", error.message
  end

  test "fetch with file attachment" do
    stub_ticks.with("op --version 2> /dev/null")
    stub_ticks.with("op account get --account myaccount 2> /dev/null")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --format \"json\" --account \"myaccount\"")
      .returns(item_with_file_json)

    stub_ticks
      .with("op read op://myvault/myitem/MY_FILE --account \"myaccount\"")
      .returns("FILE_CONTENT")

    json = JSON.parse(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1", "MY_FILE"))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1",
      "myvault/myitem/MY_FILE"=>"FILE_CONTENT"
    }

    assert_equal expected_json, json
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "1password",
            "--account", "myaccount" ]
      end
    end

    def full_item_json
      <<~JSON
        {
          "id": "ucbtiii777",
          "title": "myitem",
          "fields": [
            {
              "id": "aaaaaaaaaaaaaaaaaaaaaaaaaa",
              "section": { "id": "cccccccccccccccccccccccccc", "label": "section" },
              "type": "CONCEALED",
              "label": "SECRET1",
              "value": "VALUE1",
              "reference": "op://myvault/myitem/section/SECRET1"
            },
            {
              "id": "bbbbbbbbbbbbbbbbbbbbbbbbbb",
              "section": { "id": "dddddddddddddddddddddddddd", "label": "section" },
              "type": "CONCEALED",
              "label": "SECRET2",
              "value": "VALUE2",
              "reference": "op://myvault/myitem/section/SECRET2"
            },
            {
              "id": "eeeeeeeeeeeeeeeeeeeeeeeeee",
              "section": { "id": "ffffffffffffffffffffffff", "label": "section2" },
              "type": "CONCEALED",
              "label": "SECRET3",
              "value": "VALUE3",
              "reference": "op://myvault/myitem/section2/SECRET3"
            }
          ]
        }
      JSON
    end

    def full_item2_json
      <<~JSON
        {
          "id": "ucbtiii888",
          "title": "myitem2",
          "fields": [
            {
              "id": "gggggggggggggggggggggggggg",
              "section": { "id": "hhhhhhhhhhhhhhhhhhhhhhhhhh", "label": "section2" },
              "type": "CONCEALED",
              "label": "SECRET3",
              "value": "VALUE3",
              "reference": "op://myvault/myitem2/section2/SECRET3"
            }
          ]
        }
      JSON
    end

    def single_field_item_json
      <<~JSON
        {
          "id": "ucbtiii999",
          "title": "myitem",
          "fields": [
            {
              "id": "aaaaaaaaaaaaaaaaaaaaaaaaaa",
              "section": { "id": "cccccccccccccccccccccccccc", "label": "section" },
              "type": "CONCEALED",
              "label": "SECRET1",
              "value": "VALUE1",
              "reference": "op://myvault/myitem/section/SECRET1"
            }
          ]
        }
      JSON
    end

    def item_with_file_json
      <<~JSON
        {
          "id": "ucbtiii777",
          "title": "myitem",
          "fields": [
            {
              "id": "aaaaaaaaaaaaaaaaaaaaaaaaaa",
              "section": { "id": "cccccccccccccccccccccccccc", "label": "section" },
              "type": "CONCEALED",
              "label": "SECRET1",
              "value": "VALUE1",
              "reference": "op://myvault/myitem/section/SECRET1"
            }
          ],
          "files": [
            {
              "id": "fileid123",
              "name": "MY_FILE",
              "size": 1234,
              "content_path": "/v1/vaults/myvault/items/myitem/files/fileid123/content"
            }
          ]
        }
      JSON
    end
end
