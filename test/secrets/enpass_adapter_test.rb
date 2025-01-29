require "test_helper"

class EnpassAdapterTest < SecretAdapterTestCase
  test "fetch without CLI installed" do
    stub_command_with("enpass-cli version", false, :system)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "mynote")))
    end

    assert_equal "Enpass CLI is not installed", error.message
  end

  test "fetch one item" do
    stub_command_with("enpass-cli version", true, :system)

    stub_command
      .with("enpass-cli -json -vault vault-path show FooBar")
      .returns(<<~JSON)
      [{"category":"computer","label":"SECRET_1","login":"","password":"my-password-1","title":"FooBar","type":"password"}]
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "FooBar/SECRET_1")))

    expected_json = { "FooBar/SECRET_1" => "my-password-1" }

    assert_equal expected_json, json
  end

  test "fetch multiple items" do
    stub_command_with("enpass-cli version", true, :system)

    stub_command
      .with("enpass-cli -json -vault vault-path show FooBar")
      .returns(<<~JSON)
      [
        {"category":"computer","label":"SECRET_1","login":"","password":"my-password-1","title":"FooBar","type":"password"},
        {"category":"computer","label":"SECRET_2","login":"","password":"my-password-2","title":"FooBar","type":"password"},
        {"category":"computer","label":"SECRET_3","login":"","password":"my-password-1","title":"Hello","type":"password"}
      ]
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "FooBar/SECRET_1", "FooBar/SECRET_2")))

    expected_json = { "FooBar/SECRET_1" => "my-password-1", "FooBar/SECRET_2" => "my-password-2" }

    assert_equal expected_json, json
  end

  test "fetch all with from" do
    stub_command_with("enpass-cli version", true, :system)

    stub_command
      .with("enpass-cli -json -vault vault-path show FooBar")
      .returns(<<~JSON)
      [
        {"category":"computer","label":"SECRET_1","login":"","password":"my-password-1","title":"FooBar","type":"password"},
        {"category":"computer","label":"SECRET_2","login":"","password":"my-password-2","title":"FooBar","type":"password"},
        {"category":"computer","label":"SECRET_3","login":"","password":"my-password-1","title":"Hello","type":"password"},
        {"category":"computer","label":"","login":"","password":"my-password-3","title":"FooBar","type":"password"}
      ]
      JSON

    json = JSON.parse(shellunescape(run_command("fetch", "FooBar")))

    expected_json = { "FooBar/SECRET_1" => "my-password-1", "FooBar/SECRET_2" => "my-password-2", "FooBar" => "my-password-3" }

    assert_equal expected_json, json
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "enpass",
            "--from", "vault-path" ]
      end
    end
end
