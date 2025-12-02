require "test_helper"

class KeepassxcAdapterTest < SecretAdapterTestCase
  setup do
    @keepassxc = Kamal::Secrets::Adapters::Keepassxc.new
  end

  test "fetch via CLI (Local Mode)" do
    # Simulate when CLI is installed
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: true)

    @keepassxc.stub :ask_for_password, "dummy_pass" do
      Open3.stubs(:capture3).with("keepassxc-cli", "show", "/tmp/secrets.kdbx", "test-env", "-a", "MY_SECRET", "-q", "--show-protected", stdin_data: "dummy_pass")
        .returns(["cli_value", "", mock(success?: true)])

      secrets = @keepassxc.fetch(["MY_SECRET"], account: "/tmp/secrets.kdbx", from: "test-env")
      assert_equal({"MY_SECRET" => "cli_value"}, secrets)
    end
  end

  test "fetch via ENV (Fallback/CI Mode)" do
    # Simulate when CLI is missing
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: false)

    with_env("MY_SECRET" => "env_value") do
      @keepassxc.expects(:ask_for_password).never
      Open3.expects(:capture3).never

      secrets = @keepassxc.fetch(["MY_SECRET"], account: "ignore", from: "ignore")
      assert_equal({"MY_SECRET" => "env_value"}, secrets)
    end
  end

  test "fetch raises if CLI missing AND Env missing" do
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: false)

    error = assert_raises(RuntimeError) do
      @keepassxc.fetch(["MISSING_SECRET"], account: "ignore", from: "ignore")
    end
    assert_match(/Secret 'MISSING_SECRET' is missing in ENV./, error.message)
  end

  test "check_dependencies! is no-op (supports fallback)" do
    assert_nothing_raised { @keepassxc.send(:check_dependencies!) }
  end

  private

  def with_env(values)
    original = ENV.to_h
    values.each { |k, v| ENV[k] = v }
    yield
  ensure
    values.keys.each { |k| ENV[k] = original[k] }
  end
end
