require "test_helper"

class SecretsOnePasswordAdapterTest < ActiveSupport::TestCase
  test "login" do
    `true` # Ensure $? is 0
    Object.any_instance.stubs(:`).with("op signin --account \"myaccount\" --force --raw").returns("Logged in")

    assert_equal "Logged in", run_command("login")
  end

  test "fetch" do
    `true` # Ensure $? is 0
    Object.any_instance.stubs(:`).with("op read op://vault/item/section/foo --account \"myaccount\"").returns("bar")

    assert_equal "bar", run_command("fetch", "op://vault/item/section/foo")
  end

  test "fetch_all" do
    `true` # Ensure $? is 0
    Object.any_instance.stubs(:`)
      .with("op item get item --vault \"vault\" --fields \"label=section.SECRET1,label=section.SECRET2\" --format \"json\" --account \"myaccount\"")
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
            "reference": "op://vault/item/section/SECRET1"
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
            "reference": "op://vault/item/section/SECRET2"
          }
        ]
      JSON

    assert_equal "bar", run_command("fetch_all", "op://vault/item/section/SECRET1", "op://vault/item/section/SECRET2")
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "1password",
            "--adapter-options", "account:myaccount" ]
      end
    end
end
