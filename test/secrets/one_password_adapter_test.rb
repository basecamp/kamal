require "test_helper"

class SecretsOnePasswordAdapterTest < SecretAdapterTestCase
  test "fetch" do
    stub_ticks.with("op --version 2> /dev/null")
    stub_ticks.with("op account get --account myaccount 2> /dev/null")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --fields \"label=section.SECRET1,label=section.SECRET2,label=section2.SECRET3\" --format \"json\" --account \"myaccount\"")
      .returns(<<~JSON)
        [
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
              "id": "dddddddddddddddddddddddddd",
              "label": "section"
            },
            "type": "CONCEALED",
            "label": "SECRET2",
            "value": "VALUE2",
            "reference": "op://myvault/myitem/section/SECRET2"
          },
          {
            "id": "bbbbbbbbbbbbbbbbbbbbbbbbbb",
            "section": {
              "id": "dddddddddddddddddddddddddd",
              "label": "section2"
            },
            "type": "CONCEALED",
            "label": "SECRET3",
            "value": "VALUE3",
            "reference": "op://myvault/myitem/section2/SECRET3"
          }
        ]
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1", "section/SECRET2", "section2/SECRET3")))

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
      .with("op item get myitem --vault \"myvault\" --fields \"label=section.SECRET1,label=section.SECRET2\" --format \"json\" --account \"myaccount\"")
      .returns(<<~JSON)
        [
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
              "id": "dddddddddddddddddddddddddd",
              "label": "section"
            },
            "type": "CONCEALED",
            "label": "SECRET2",
            "value": "VALUE2",
            "reference": "op://myvault/myitem/section/SECRET2"
          }
        ]
      JSON

    stub_ticks
      .with("op item get myitem2 --vault \"myvault\" --fields \"label=section2.SECRET3\" --format \"json\" --account \"myaccount\"")
      .returns(<<~JSON)
        {
          "id": "aaaaaaaaaaaaaaaaaaaaaaaaaa",
          "section": {
            "id": "cccccccccccccccccccccccccc",
            "label": "section"
          },
          "type": "CONCEALED",
          "label": "SECRET3",
          "value": "VALUE3",
          "reference": "op://myvault/myitem2/section/SECRET3"
        }
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "op://myvault", "myitem/section/SECRET1", "myitem/section/SECRET2", "myitem2/section2/SECRET3")))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1",
      "myvault/myitem/section/SECRET2"=>"VALUE2",
      "myvault/myitem2/section/SECRET3"=>"VALUE3"
    }

    assert_equal expected_json, json
  end

  test "fetch with signin, no session" do
    stub_ticks.with("op --version 2> /dev/null")

    stub_ticks_with("op account get --account myaccount 2> /dev/null", succeed: false)
    stub_ticks_with("op signin --account \"myaccount\" --force --raw", succeed: true).returns("")

    stub_ticks
      .with("op item get myitem --vault \"myvault\" --fields \"label=section.SECRET1\" --format \"json\" --account \"myaccount\"")
      .returns(single_item_json)

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1")))

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
      .with("op item get myitem --vault \"myvault\" --fields \"label=section.SECRET1\" --format \"json\" --account \"myaccount\" --session \"1234567890\"")
      .returns(single_item_json)

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1")))

    expected_json = {
      "myvault/myitem/section/SECRET1"=>"VALUE1"
    }

    assert_equal expected_json, json
  end

  test "fetch without CLI installed" do
    stub_ticks_with("op --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "--from", "op://myvault/myitem", "section/SECRET1", "section/SECRET2", "section2/SECRET3")))
    end
    assert_equal "1Password CLI is not installed", error.message
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

    def single_item_json
      <<~JSON
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
        }
      JSON
    end
end
