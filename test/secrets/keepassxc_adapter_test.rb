require "test_helper"

class KeepassxcAdapterTest < SecretAdapterTestCase
  test "fetch one entry password" do
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: true)
    stub_ticks
      .with("keepassxc-cli show --show-protected --attributes Password vault-path app/KAMAL_REGISTRY_PASSWORD")
      .returns("super-secret\n")

    json = JSON.parse(run_command("fetch", "app/KAMAL_REGISTRY_PASSWORD"))

    assert_equal({ "app/KAMAL_REGISTRY_PASSWORD" => "super-secret" }, json)
  end

  test "fetch parses labeled output" do
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: true)
    stub_ticks
      .with("keepassxc-cli show --show-protected --attributes Password vault-path app/DB_PASSWORD")
      .returns("Password: db-secret\n")

    json = JSON.parse(run_command("fetch", "app/DB_PASSWORD"))

    assert_equal({ "app/DB_PASSWORD" => "db-secret" }, json)
  end

  test "fetch uses KEEPASSXC_PASSWORD when available" do
    begin
      ENV["KEEPASSXC_PASSWORD"] = "db-pass"

      stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: true)
      command = "printf %s\\\\n db-pass | " \
        "keepassxc-cli show --show-protected --attributes Password --pw-stdin " \
        "vault-path app/RAILS_MASTER_KEY"
      stub_ticks
        .with(command)
        .returns("rails-secret\n")

      json = JSON.parse(run_command("fetch", "app/RAILS_MASTER_KEY"))

      assert_equal({ "app/RAILS_MASTER_KEY" => "rails-secret" }, json)
    ensure
      ENV.delete("KEEPASSXC_PASSWORD")
    end
  end

  test "fetch without --from" do
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: true)

    error = assert_raises RuntimeError do
      run_command_without_from("fetch", "app/KAMAL_REGISTRY_PASSWORD")
    end

    assert_equal "Missing database path from '--from=/path/to/database.kdbx' option", error.message
  end

  test "fetch without CLI installed" do
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      run_command("fetch", "app/KAMAL_REGISTRY_PASSWORD")
    end

    assert_equal "KeepassXC CLI is not installed", error.message
  end

  private
    def run_command(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "keepassxc",
            "--from", "vault-path" ]
      end
    end

    def run_command_without_from(*command)
      stdouted do
        Kamal::Cli::Secrets.start \
          [ *command,
            "-c", "test/fixtures/deploy_with_accessories.yml",
            "--adapter", "keepassxc" ]
      end
    end
end
