require "test_helper"

class ProtonPassAdapterTest < SecretAdapterTestCase
  test "fetch without CLI installed" do
    stub_ticks_with("pass-cli --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(run_command("fetch", "REGISTRY_PASSWORD"))
    end

    assert_equal "Proton Pass CLI is not installed", error.message
  end

  test "fetch single password field" do
    stub_ticks_with("pass-cli --version 2> /dev/null", succeed: true)
    stub_ticks_with("pass-cli info 2> /dev/null", succeed: true)

    stub_ticks
      .with("pass-cli item view pass://MyVault/MyItem/password --output json 2>&1")
      .returns("secret123\n")

    json = JSON.parse(run_command("fetch", "--from", "MyVault", "MyItem"))

    expected_json = { "MyVault/MyItem" => "secret123" }

    assert_equal expected_json, json
  end

  test "fetch specific field" do
    stub_ticks_with("pass-cli --version 2> /dev/null", succeed: true)
    stub_ticks_with("pass-cli info 2> /dev/null", succeed: true)

    stub_ticks
      .with("pass-cli item view pass://MyVault/MyItem/username --output json 2>&1")
      .returns("myuser\n")

    json = JSON.parse(run_command("fetch", "--from", "MyVault", "MyItem/username"))

    expected_json = { "MyVault/MyItem/username" => "myuser" }

    assert_equal expected_json, json
  end

  test "fetch multiple fields" do
    stub_ticks_with("pass-cli --version 2> /dev/null", succeed: true)
    stub_ticks_with("pass-cli info 2> /dev/null", succeed: true)

    stub_ticks
      .with("pass-cli item view pass://MyVault/MyItem/password --output json 2>&1")
      .returns("secret123\n")

    stub_ticks
      .with("pass-cli item view pass://MyVault/MyItem/username --output json 2>&1")
      .returns("myuser\n")

    json = JSON.parse(run_command("fetch", "--from", "MyVault", "MyItem", "MyItem/username"))

    expected_json = {
      "MyVault/MyItem" => "secret123",
      "MyVault/MyItem/username" => "myuser"
    }

    assert_equal expected_json, json
  end

  test "fetch from multiple vaults" do
    stub_ticks_with("pass-cli --version 2> /dev/null", succeed: true)
    stub_ticks_with("pass-cli info 2> /dev/null", succeed: true)

    stub_ticks
      .with("pass-cli item view pass://Vault1/Item1/password --output json 2>&1")
      .returns("secret1\n")

    stub_ticks
      .with("pass-cli item view pass://Vault2/Item2/username --output json 2>&1")
      .returns("user2\n")

    json = JSON.parse(run_command("fetch", "Vault1/Item1", "Vault2/Item2/username"))

    expected_json = {
      "Vault1/Item1" => "secret1",
      "Vault2/Item2/username" => "user2"
    }

    assert_equal expected_json, json
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "proton_pass" ]
      end
    end
end
