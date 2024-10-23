require "test_helper"

class LastPassAdapterTest < SecretAdapterTestCase
  setup do
    `true` # Ensure $? is 0
  end

  test "fetch" do
    stub_ticks.with("lpass --version 2> /dev/null")
    stub_ticks.with("lpass status --color never").returns("Logged in as email@example.com.")

    stub_ticks
      .with("lpass show SECRET1 FOLDER1/FSECRET1 FOLDER1/FSECRET2 --json")
      .returns(<<~JSON)
        [
          {
            "id": "1234567891234567891",
            "name": "SECRET1",
            "fullname": "SECRET1",
            "username": "",
            "password": "secret1",
            "last_modified_gmt": "1724926054",
            "last_touch": "1724926639",
            "group": "",
            "url": "",
            "note": ""
          },
          {
            "id": "1234567891234567892",
            "name": "FSECRET1",
            "fullname": "FOLDER1/FSECRET1",
            "username": "",
            "password": "fsecret1",
            "last_modified_gmt": "1724926084",
            "last_touch": "1724926635",
            "group": "Folder",
            "url": "",
            "note": ""
          },
          {
            "id": "1234567891234567893",
            "name": "FSECRET2",
            "fullname": "FOLDER1/FSECRET2",
            "username": "",
            "password": "fsecret2",
            "last_modified_gmt": "1724926084",
            "last_touch": "1724926635",
            "group": "Folder",
            "url": "",
            "note": ""
          }
        ]
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "SECRET1", "FOLDER1/FSECRET1", "FOLDER1/FSECRET2")))

    expected_json = {
      "SECRET1"=>"secret1",
      "FOLDER1/FSECRET1"=>"fsecret1",
      "FOLDER1/FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch with from" do
    stub_ticks.with("lpass --version 2> /dev/null")
    stub_ticks.with("lpass status --color never").returns("Logged in as email@example.com.")

    stub_ticks
      .with("lpass show FOLDER1/FSECRET1 FOLDER1/FSECRET2 --json")
      .returns(<<~JSON)
        [
          {
            "id": "1234567891234567892",
            "name": "FSECRET1",
            "fullname": "FOLDER1/FSECRET1",
            "username": "",
            "password": "fsecret1",
            "last_modified_gmt": "1724926084",
            "last_touch": "1724926635",
            "group": "Folder",
            "url": "",
            "note": ""
          },
          {
            "id": "1234567891234567893",
            "name": "FSECRET2",
            "fullname": "FOLDER1/FSECRET2",
            "username": "",
            "password": "fsecret2",
            "last_modified_gmt": "1724926084",
            "last_touch": "1724926635",
            "group": "Folder",
            "url": "",
            "note": ""
          }
        ]
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "FOLDER1", "FSECRET1", "FSECRET2")))

    expected_json = {
      "FOLDER1/FSECRET1"=>"fsecret1",
      "FOLDER1/FSECRET2"=>"fsecret2"
    }

    assert_equal expected_json, json
  end

  test "fetch with signin" do
    stub_ticks.with("lpass --version 2> /dev/null")

    stub_ticks_with("lpass status --color never", succeed: false).returns("Not logged in.")
    stub_ticks_with("lpass login email@example.com", succeed: true).returns("")
    stub_ticks.with("lpass show SECRET1 --json").returns(single_item_json)

    json = JSON.parse(shellunescape(run_command("fetch", "SECRET1")))

    expected_json = {
      "SECRET1"=>"secret1"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_ticks_with("lpass --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "SECRET1", "FOLDER1/FSECRET1", "FOLDER1/FSECRET2")))
    end
    assert_equal "LastPass CLI is not installed", error.message
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "lastpass",
            "--account", "email@example.com" ]
      end
    end

    def single_item_json
      <<~JSON
        [
          {
            "id": "1234567891234567891",
            "name": "SECRET1",
            "fullname": "SECRET1",
            "username": "",
            "password": "secret1",
            "last_modified_gmt": "1724926054",
            "last_touch": "1724926639",
            "group": "",
            "url": "",
            "note": ""
          }
        ]
      JSON
    end
end
