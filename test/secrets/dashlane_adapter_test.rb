require "test_helper"

class DashlaneAdapterTest < SecretAdapterTestCase
  setup do
    @adapter = Kamal::Secrets::Adapters::Dashlane.new
  end

  test "fetch without CLI installed" do
    stub_cli_installed(false)

    assert_raises(RuntimeError, "Dashlane CLI is not installed") do
      run_command("fetch", *secrets.keys)
    end
  end

  test "fetch with failed login" do
    stub_cli_installed(true)
    stub_status(false)
    stub_login(false)

    assert_raises(RuntimeError, "Failed to login to or unlock Dashlane") do
      @adapter.fetch(secrets.keys, account: account)
    end
  end

  test "fetch with successful login" do
    stub_cli_installed(true)
    stub_status(false)
    stub_login(true)
    stub_dashlane_password(found: true, secrets: secrets)
    stub_dashlane_secret(found: true, secrets: secrets)

    result = @adapter.fetch(secrets.keys, account: account)

    assert_equal(result.sort, secrets.sort)
  end

  test "fetch when already logged in" do
    setup_logged_in
    stub_dashlane_password(found: true, secrets: secrets)
    stub_dashlane_secret(found: true, secrets: secrets)

    result = @adapter.fetch(secrets.keys, account: account)

    assert_equal(result.sort, secrets.sort)
  end

  test "fetch with missing entries" do
    setup_logged_in
    stub_dashlane_password(found: false, secrets: secrets)
    stub_dashlane_secret(found: false, secrets: secrets)

    assert_raises RuntimeError, "Could not find #{secrets.keys.join(", ")} in Dashlane passwords or secrets" do
      @adapter.fetch(secrets.keys, account: account)
    end
  end

  test "fetch dashlane passwords and no secrets" do
    only_passwords = secrets.select { |k| k.match? "PASSWORD" }
    setup_logged_in
    stub_dashlane_password(found: true, secrets: only_passwords)
    stub_dashlane_secret(found: false, secrets: only_passwords)

    result = @adapter.fetch(only_passwords.keys, account: account)

    assert_equal(result.sort, only_passwords.sort)
  end

  test "fetch dashlane secrets and no passwords" do
    only_secrets = secrets.select { |k| k.match? "SECRET" }
    setup_logged_in
    stub_dashlane_password(found: false, secrets: only_secrets)
    stub_dashlane_secret(found: true, secrets: only_secrets)

    result = @adapter.fetch(only_secrets.keys, account: account)

    assert_equal(result.sort, only_secrets.sort)
  end

  private
    def stub_cli_installed(installed)
      stub_ticks_with("dcli --version 2> /dev/null", succeed: installed)
    end

    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "dashlane",
            "--account", "email@example.com" ]
      end
      Kamal::Secrets::Adapters::Dashlane.new
    end

    def secrets
      { "SECRET1" => "secret_password", "PASSWORD1" => "password_password" }
    end

    def stub_status(logged_in)
      if logged_in
        stub_ticks_with("dcli status 2> /dev/null", succeed: true).returns(<<~STATUS)
        Logged in: yes
        Login: #{account}
        Locked: no
        STATUS
      else
        stub_ticks_with("dcli status 2> /dev/null", succeed: false)
      end
    end

    def stub_login(success)
      @adapter.stubs(:system).with { "dcli sync 2> /dev/null" && (success ? `true` : `false`) }
    end

    def account
      "email@example.com"
    end

    def stub_dashlane_password(found:, secrets:)
      output = if found
        "[{\"id\":\"{ZD26708D-5KJ4-12KI-5K0G-4J34FFF67JT3}\",\"creationDatetime\":\"1777982025\",\"lastBackupTime\":\"0\",\"lastUse\":\"1777982025\",\"localeFormat\":\"UNIVERSAL\",\"userModificationDatetime\":\"1777982025\",\"autoLogin\":\"true\",\"autoProtected\":\"false\",\"checked\":\"false\",\"password\":\"password_password\",\"status\":\"ACCOUNT_NOT_VERIFIED\",\"strength\":\"0\",\"subdomainOnly\":\"false\",\"title\":\"PASSWORD1\",\"useFixedUrl\":\"true\",\"linkedServices\":\"{\\\"associated_domains\\\":[]}\",\"modificationDatetime\":\"1777982025\"}]"
      else
        "[]"
      end
      stub_ticks.with("dcli password #{secrets.keys.join(" ")} -o json").returns(output)
    end

    def stub_dashlane_secret(found:, secrets:)
      output = if found
        "[{\"id\":\"{ZD26708D-5KJ4-12KI-5K0G-4J34FFF67JT2}\",\"creationDatetime\":\"1777896821\",\"lastBackupTime\":\"0\",\"lastUse\":\"1777896821\",\"localeFormat\":\"UNIVERSAL\",\"attachments\":\"[]\",\"userModificationDatetime\":\"1777896821\",\"title\":\"SECRET1\",\"content\":\"secret_password\",\"category\":\"noCategory\",\"secured\":\"false\",\"type\":\"GRAY\",\"creationDate\":\"1777896821\",\"updateDate\":\"1777896821\"}]"
      else
        "[]"
      end
      stub_ticks.with("dcli secret #{secrets.keys.join(" ")} -o json").returns(output)
    end

    def setup_logged_in
      stub_cli_installed(true)
      stub_status(true)
    end
end
