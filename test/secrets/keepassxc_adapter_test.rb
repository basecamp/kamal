require "test_helper"

class KeepassxcAdapterTest < SecretAdapterTestCase
  setup do
    @keepassxc = Kamal::Secrets::Adapters::Keepassxc.new
  end

  test "fetch specific secrets in local mode calling CLI" do
    with_ci_mode(false) do
      @keepassxc.stub :ask_for_password, "dummy_master_pass" do
        @keepassxc.stub :run_command, "secret_value" do
          secrets = @keepassxc.fetch([ "MY_SECRET" ], account: "/tmp/secrets.kdbx", from: "test-env")
          assert_equal({ "MY_SECRET" => "secret_value" }, secrets)
        end
      end
    end
  end

  test "fetch password field uses no -a flag" do
    with_ci_mode(false) do
      @keepassxc.stub :ask_for_password, "pass" do
        verifier = ->(cmd, account, from, *args, session:) {
          if args.include?("-a")
            raise "Error: 'password' field should not use -a flag"
          end
          "pw_value"
        }

        @keepassxc.stub :run_command, verifier do
          secrets = @keepassxc.fetch([ "password" ], account: "/tmp/db.kdbx", from: "entry")
          assert_equal({ "password" => "pw_value" }, secrets)
        end
      end
    end
  end

  test "fetch secrets in CI mode reads from ENV" do
    with_ci_mode(true) do
      with_env("MY_SECRET" => "env_value") do
        secrets = @keepassxc.fetch([ "MY_SECRET" ], account: "ignore", from: "ignore")
        assert_equal({ "MY_SECRET" => "env_value" }, secrets)
      end
    end
  end

  test "fetch secrets in CI mode fails fast if ENV missing" do
    with_ci_mode(true) do
      error = assert_raises(RuntimeError) do
        @keepassxc.fetch([ "MISSING_SECRET" ], account: "ignore", from: "ignore")
      end
      assert_match /Missing ENV secret 'MISSING_SECRET' in CI mode/, error.message
    end
  end

  test "login returns dummy session in CI mode" do
    with_ci_mode(true) do
      assert_equal "ci-session", @keepassxc.send(:login, "account")
    end
  end

  test "dependency check is skipped in CI mode" do
    with_ci_mode(true) do
      # Should NOT raise even if we force cli_installed? to false
      @keepassxc.stub :cli_installed?, false do
        assert_nothing_raised { @keepassxc.send(:check_dependencies!) }
      end
    end
  end

  test "dependency check raises in local mode if CLI missing" do
    with_ci_mode(false) do
      @keepassxc.stub :cli_installed?, false do
        assert_raises(RuntimeError) { @keepassxc.send(:check_dependencies!) }
      end
    end
  end

  private
    def with_ci_mode(enabled)
      key = "CI"
      original = ENV[key]
      ENV[key] = enabled ? "true" : nil
      yield
    ensure
      ENV[key] = original
    end

    def with_env(values)
      original = ENV.to_h
      values.each { |k, v| ENV[k] = v }
      yield
    ensure
      values.keys.each { |k| ENV[k] = original[k] }
    end
end
