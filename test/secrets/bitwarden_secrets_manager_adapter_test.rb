require "test_helper"

class BitwardenSecretsManagerAdapterTest < SecretAdapterTestCase
  test "fetch with no parameters" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_login

    error = assert_raises RuntimeError do
      (shellunescape(run_command("fetch")))
    end
    assert_equal("You must specify what to retrieve from Bitwarden Secrets Manager", error.message)
  end

  test "fetch all" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_login
    stub_command
      .with("bws secret list -o env")
      .returns("KAMAL_REGISTRY_PASSWORD=\"some_password\"\nMY_OTHER_SECRET=\"my=weird\"secret\"")

    expected = '{"KAMAL_REGISTRY_PASSWORD":"some_password","MY_OTHER_SECRET":"my\=weird\"secret"}'
    actual = shellunescape(run_command("fetch", "all"))
    assert_equal expected, actual
  end

  test "fetch all with from" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_login
    stub_command
      .with("bws secret list -o env 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns("KAMAL_REGISTRY_PASSWORD=\"some_password\"\nMY_OTHER_SECRET=\"my=weird\"secret\"")

    expected = '{"KAMAL_REGISTRY_PASSWORD":"some_password","MY_OTHER_SECRET":"my\=weird\"secret"}'
    actual = shellunescape(run_command("fetch", "all", "--from", "82aeb5bd-6958-4a89-8197-eacab758acce"))
    assert_equal expected, actual
  end

  test "fetch item" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_login
    stub_command
      .with("bws secret get -o env 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns("KAMAL_REGISTRY_PASSWORD=\"some_password\"")

    expected = '{"KAMAL_REGISTRY_PASSWORD":"some_password"}'
    actual = shellunescape(run_command("fetch", "82aeb5bd-6958-4a89-8197-eacab758acce"))
    assert_equal expected, actual
  end

  test "fetch with multiple items" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_login
    stub_command
      .with("bws secret get -o env 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns("KAMAL_REGISTRY_PASSWORD=\"some_password\"")
    stub_command
      .with("bws secret get -o env 6f8cdf27-de2b-4c77-a35d-07df8050e332")
      .returns("MY_OTHER_SECRET=\"my=weird\"secret\"")

    expected = '{"KAMAL_REGISTRY_PASSWORD":"some_password","MY_OTHER_SECRET":"my\=weird\"secret"}'
    actual = shellunescape(run_command("fetch", "82aeb5bd-6958-4a89-8197-eacab758acce", "6f8cdf27-de2b-4c77-a35d-07df8050e332"))
    assert_equal expected, actual
  end

  test "fetch all empty" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_login
    stub_command_with("bws secret list -o env").returns("Error:\n0: Received error message from server")

    error = assert_raises RuntimeError do
      (shellunescape(run_command("fetch", "all")))
    end
    assert_equal("Could not read secrets from Bitwarden Secrets Manager", error.message)
  end

  test "fetch nonexistent item" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_login
    stub_command_with("bws secret get -o env 82aeb5bd-6958-4a89-8197-eacab758acce")
      .returns("ERROR (RuntimeError): Could not read 82aeb5bd-6958-4a89-8197-eacab758acce from Bitwarden Secrets Manager")

    error = assert_raises RuntimeError do
      (shellunescape(run_command("fetch", "82aeb5bd-6958-4a89-8197-eacab758acce")))
    end
    assert_equal("Could not read 82aeb5bd-6958-4a89-8197-eacab758acce from Bitwarden Secrets Manager", error.message)
  end

  test "fetch with no access token" do
    stub_command(:system).with("bws --version", err: File::NULL)
    stub_command_with("bws run 'echo OK'")

    error = assert_raises RuntimeError do
      (shellunescape(run_command("fetch", "all")))
    end
    assert_equal("Could not authenticate to Bitwarden Secrets Manager. Did you set a valid access token?", error.message)
  end

  test "fetch without CLI installed" do
    stub_command_with("bws --version", false, :system)

    error = assert_raises RuntimeError do
      shellunescape(run_command("fetch"))
    end
    assert_equal "Bitwarden Secrets Manager CLI is not installed", error.message
  end

  private
    def stub_login
      stub_command.with("bws run 'echo OK'").returns("OK")
    end

    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "--adapter", "bitwarden-sm" ]
      end
    end
end
