require "test_helper"
require "open3"

class PruneProtectionTest < ActiveSupport::TestCase
  test "protected current target survives newer stopped containers without consuming retention" do
    current, newer, oldest = %w[a b c].map { |c| c * 64 }
    config = Kamal::Configuration.new({ service: "app", image: "dhh/app", servers: [ "1.1.1.1" ], registry: { "username" => "dhh", "password" => "secret" }, builder: { "arch" => "amd64" } }, version: "123")
    command = Kamal::Commands::Prune.new(config).app_containers(retain: 1, protected_ids: [ current ]).join(" ")
    # Fake Docker returns creation order: failed release, sleeping current, old history.
    script = "docker() { case \"$1\" in ps) printf '%s\\n' #{newer} #{current} #{oldest} ;; rm) printf '%s\\n' \"$2\" ;; esac; }; #{command}"
    output, error, status = Open3.capture3("bash", "-c", script)
    assert status.success?, error
    assert_equal [ oldest ], output.lines.map(&:strip)
    assert_includes command, "--no-trunc"
  end

  test "reject invalid protected IDs before generating a shell command" do
    config = stub
    assert_raises(ArgumentError) { Kamal::Commands::Prune.new(config).app_containers(retain: 1, protected_ids: [ "$(whoami)" ]) }
  end

  test "extracts all registered targets and ignores unrelated services" do
    json = {
      "app-web" => { "targets" => [ "active:80" ], "read_targets" => [ "reader:80" ],
        "rollout" => { "enabled" => false, "targets" => [ "rollout:80" ], "read_targets" => [ "rollout-reader:80", "reader:80" ] } },
      "unrelated" => { "targets" => [ "[::1]:80" ] }
    }.to_json
    assert_equal %w[active reader rollout rollout-reader], Kamal::Commands::Prune.new(stub).registered_containers(json, services: [ "app-web" ])
  end

  test "malformed target lists fail closed" do
    [ nil, "not a list", [ nil ], [ "--unsafe:80" ] ].each do |targets|
      json = { "app-web" => { "targets" => targets } }.to_json
      assert_raises(ArgumentError) { Kamal::Commands::Prune.new(stub).registered_containers(json, services: [ "app-web" ]) }
    end
  end
end
