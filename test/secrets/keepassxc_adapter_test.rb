require "test_helper"

class KeepassxcAdapterTest < SecretAdapterTestCase
  setup do
    @keepassxc = Kamal::Secrets::Adapters::Keepassxc.new
  end

  test "fetch via CLI" do
    # Simulate when CLI is installed
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: true)

    @keepassxc.stub :ask_for_password, "dummy_pass" do
      Open3.stubs(:capture3).with("keepassxc-cli", "show", "/tmp/secrets.kdbx", "test-env", "-a", "MY_SECRET", "-q", "--show-protected", stdin_data: "dummy_pass")
        .returns([ "cli_value", "", mock(success?: true) ])

      secrets = @keepassxc.fetch([ "MY_SECRET" ], account: "/tmp/secrets.kdbx", from: "test-env")
      assert_equal({ "MY_SECRET" => "cli_value" }, secrets)
    end
  end

  test "check_dependencies! raises if CLI is missing" do
    stub_ticks_with("keepassxc-cli --version 2> /dev/null", succeed: false)

    error = assert_raises(RuntimeError) do
      @keepassxc.send(:check_dependencies!)
    end
    assert_match(/KeePassXC CLI is not installed/, error.message)
  end
end
