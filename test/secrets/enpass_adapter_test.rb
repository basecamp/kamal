require "test_helper"

class EnpassAdapterTest < SecretAdapterTestCase
  setup do
    `true` # Ensure $? is 0
  end

  test "fetch without CLI installed" do
    stub_ticks_with("enpass-cli version 2> /dev/null", succeed: false)

    error = assert_raises RuntimeError do
      JSON.parse(shellunescape(run_command("fetch", "mynote")))
    end

    assert_equal "Enpass CLI is not installed", error.message
  end

  test "fetch one item" do
    stub_ticks_with("enpass-cli version 2> /dev/null")

    stderr_response = <<~RESULT
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label: SECRET_1  password: my-password-1
    RESULT

    Open3.stubs(:capture3).returns([ "", stderr_response, OpenStruct.new(success?: true) ])

    json = JSON.parse(shellunescape(run_command("fetch", "FooBar/SECRET_1")))

    expected_json = { "FooBar/SECRET_1" => "my-password-1" }

    assert_equal expected_json, json
  end

  test "fetch multiple items" do
    stub_ticks_with("enpass-cli version 2> /dev/null")

    stderr_response = <<~RESULT
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label: SECRET_1  password: my-password-1
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label: SECRET_2  password: my-password-2
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: Hello  login:   cat.: computer  label: SECRET_3  password: my-password-3
    RESULT

    Open3.stubs(:capture3).returns([ "", stderr_response, OpenStruct.new(success?: true) ])

    json = JSON.parse(shellunescape(run_command("fetch", "FooBar/SECRET_1", "FooBar/SECRET_2")))

    expected_json = { "FooBar/SECRET_1" => "my-password-1", "FooBar/SECRET_2" => "my-password-2" }

    assert_equal expected_json, json
  end

  test "fetch multiple items with from" do
    stub_ticks_with("enpass-cli version 2> /dev/null")

    stderr_response = <<~RESULT
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label: SECRET_1  password: my-password-1
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label: SECRET_2  password: my-password-2
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: Hello  login:   cat.: computer  label: SECRET_3  password: my-password-3
    RESULT

    Open3.stubs(:capture3).returns([ "", stderr_response, OpenStruct.new(success?: true) ])

    json = JSON.parse(shellunescape(run_command("fetch", "--from", "FooBar", "SECRET_1", "SECRET_2")))

    expected_json = { "FooBar/SECRET_1" => "my-password-1", "FooBar/SECRET_2" => "my-password-2" }

    assert_equal expected_json, json
  end

  test "fetch all with from" do
    stub_ticks_with("enpass-cli version 2> /dev/null")

    stderr_response = <<~RESULT
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label: SECRET_1  password: my-password-1
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label: SECRET_2  password: my-password-2
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: Hello  login:   cat.: computer  label: SECRET_3  password: my-password-3
    time="2024-11-03T13:34:39+01:00" level=info msg="> title: FooBar  login:   cat.: computer  label:   password: my-password-3
    RESULT

    Open3.stubs(:capture3).returns([ "", stderr_response, OpenStruct.new(success?: true) ])

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
            "--account", "vault-path" ]
      end
    end
end
