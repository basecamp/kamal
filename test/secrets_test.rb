require "test_helper"

class SecretsTest < ActiveSupport::TestCase
  test "fetch" do
    with_test_secrets("secrets" => "SECRET=ABC") do
      assert_equal "ABC", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET"]
    end
  end

  test "synchronized_fetch" do
    with_test_secrets("secrets" => "SECRET=ABC") do
      assert_equal "ABC", Kamal::Secrets.new(secrets_path: ".kamal/secrets").send(:synchronized_fetch, "SECRET")
    end
  end

  test "key?" do
    with_test_secrets("secrets" => "SECRET1=ABC") do
      assert Kamal::Secrets.new(secrets_path: ".kamal/secrets").key?("SECRET1")
      assert_not Kamal::Secrets.new(secrets_path: ".kamal/secrets").key?("SECRET2")
    end
  end

  test "command interpolation" do
    with_test_secrets("secrets" => "SECRET=$(echo ABC)") do
      assert_equal "ABC", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET"]
    end
  end

  test "command interpolation preserves dollar signs in the output" do
    # The command outputs pa$1wor$D. Built with tr because "$word" in the
    # command text itself is substituted before running.
    with_test_secrets("secrets" => "SECRET=$(echo 'paX1worXD' | tr X '$')") do
      assert_equal "pa$1wor$D", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET"]
    end
  end

  test "command interpolation still substitutes variables in the command" do
    with_test_secrets("secrets" => "SECRET1=ABC\nSECRET2=$(echo ${SECRET1}DEF)") do
      assert_equal "ABCDEF", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET2"]
    end
  end

  test "inline kamal secrets commands preserve dollar signs in extracted values" do
    # Single-quoted so the stored value matches what an inlined
    # "kamal secrets fetch" returns: shell-escaped JSON.
    secrets_json = { "vault/password" => "pa$1wor$D" }.to_json.shellescape
    with_test_secrets("secrets" => "SECRETS='#{secrets_json}'\nPASSWORD=$(kamal secrets extract vault/password ${SECRETS})") do
      assert_equal "pa$1wor$D", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["PASSWORD"]
    end
  end

  test "variable references" do
    with_test_secrets("secrets" => "SECRET1=ABC\nSECRET2=${SECRET1}DEF") do
      assert_equal "ABC", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET1"]
      assert_equal "ABCDEF", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET2"]
    end
  end

  test "env references" do
    with_test_secrets("secrets" => "SECRET1=$SECRET1") do
      ENV["SECRET1"] = "ABC"
      assert_equal "ABC", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET1"]
    end
  end

  test "secrets file value overrides env" do
    with_test_secrets("secrets" => "SECRET1=DEF") do
      ENV["SECRET1"] = "ABC"
      assert_equal "DEF", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET1"]
    end
  end

  test "destinations" do
    with_test_secrets("secrets.dest" => "SECRET=DEF", "secrets" => "SECRET=ABC", "secrets-common" => "SECRET=GHI\nSECRET2=JKL") do
      assert_equal "ABC", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET"]
      assert_equal "DEF", Kamal::Secrets.new(secrets_path: ".kamal/secrets", destination: "dest")["SECRET"]
      assert_equal "GHI", Kamal::Secrets.new(secrets_path: ".kamal/secrets", destination: "nodest")["SECRET"]

      assert_equal "JKL", Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET2"]
      assert_equal "JKL", Kamal::Secrets.new(secrets_path: ".kamal/secrets", destination: "dest")["SECRET2"]
      assert_equal "JKL", Kamal::Secrets.new(secrets_path: ".kamal/secrets", destination: "nodest")["SECRET2"]
    end
  end

  test "no secrets files" do
    with_test_secrets do
      error = assert_raises(Kamal::ConfigurationError) do
        Kamal::Secrets.new(secrets_path: ".kamal/secrets")["SECRET"]
      end
      assert_equal "Secret 'SECRET' not found, no secret files (.kamal/secrets-common, .kamal/secrets) provided", error.message

      error = assert_raises(Kamal::ConfigurationError) do
        Kamal::Secrets.new(secrets_path: ".kamal/secrets", destination: "dest")["SECRET"]
      end
      assert_equal "Secret 'SECRET' not found, no secret files (.kamal/secrets-common, .kamal/secrets.dest) provided", error.message
    end
  end

  test "custom secrets_path" do
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("custom/path")
        File.write("custom/path/secrets", "SECRET=CUSTOM")

        assert_equal "CUSTOM", Kamal::Secrets.new(secrets_path: "custom/path/secrets")["SECRET"]
      end
    end
  end

  test "custom secrets_path with destination" do
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("custom/path")
        File.write("custom/path/secrets", "SECRET=BASE")
        File.write("custom/path/secrets.prod", "SECRET=PROD")

        assert_equal "BASE", Kamal::Secrets.new(secrets_path: "custom/path/secrets")["SECRET"]
        assert_equal "PROD", Kamal::Secrets.new(secrets_path: "custom/path/secrets", destination: "prod")["SECRET"]
      end
    end
  end

  test "custom secrets_path with common file" do
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("custom/path")
        File.write("custom/path/secrets-common", "COMMON=SHARED\nSECRET=COMMON")
        File.write("custom/path/secrets", "SECRET=OVERRIDE")

        secrets = Kamal::Secrets.new(secrets_path: "custom/path/secrets")
        assert_equal "SHARED", secrets["COMMON"]
        assert_equal "OVERRIDE", secrets["SECRET"]
      end
    end
  end

  test "default secrets_path" do
    with_test_secrets("secrets" => "SECRET=ABC") do
      assert_equal "ABC", Kamal::Secrets.new["SECRET"]
    end
  end

  test "custom secrets_path error message" do
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        error = assert_raises(Kamal::ConfigurationError) do
          Kamal::Secrets.new(secrets_path: "custom/path/secrets")["SECRET"]
        end
        assert_equal "Secret 'SECRET' not found, no secret files (custom/path/secrets-common, custom/path/secrets) provided", error.message
      end
    end
  end
end
