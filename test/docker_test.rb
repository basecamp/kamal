require "test_helper"

class DockerTest < ActiveSupport::TestCase
  test "included files runs the builder's check commands" do
    Kamal::Docker.expects(:system).with do |*command|
      command[0..4] == [ "container", "build", "--tag", "kamal-local-build-check", "--file" ] &&
        command[5].is_a?(String) && command[6] == "."
    end.returns(true)
    Open3.expects(:capture3)
      .with("container", "run", "--rm", "kamal-local-build-check")
      .returns([ "app.rb\nDockerfile\n", "", stub(success?: true) ])

    assert_equal [ "app.rb", "Dockerfile" ], Kamal::Docker.included_files(builder: apple_container_builder)
  end

  test "included files raises when the check image fails" do
    Kamal::Docker.expects(:system).returns(true)
    Open3.expects(:capture3)
      .returns([ "", "check failed", stub(success?: false) ])

    error = assert_raises(RuntimeError) do
      Kamal::Docker.included_files(builder: apple_container_builder)
    end

    assert_equal "failed to run check image:\ncheck failed", error.message
  end

  private
    def apple_container_builder
      config = Kamal::Configuration.create_from \
        config_file: Pathname.new(File.expand_path("fixtures/deploy_with_apple_container.yml", __dir__))

      Kamal::Commands::Builder.new(config)
    end
end
