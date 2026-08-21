require "test_helper"

class CommandsBuilderTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], builder: { "arch" => "amd64" } }
  end

  test "target linux/amd64 locally by default" do
    builder = new_builder_command(builder: { "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "target specified arch locally by default" do
    builder = new_builder_command(builder: { "arch" => [ "amd64" ] })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "target apple container engine locally" do
    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "amd64" })

    assert_equal "apple_container", builder.name
    assert_equal \
      "container build --platform linux/amd64 -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile . 2>&1 && container image push dhh/app:123 && container image push dhh/app:latest",
      builder.push.join(" ")
  end

  test "apple container engine uses repeated platform arguments" do
    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => [ "amd64", "arm64" ] })

    assert_equal \
      "container build --platform linux/amd64 --platform linux/arm64 -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile . 2>&1 && container image push dhh/app:123 && container image push dhh/app:latest",
      builder.push.join(" ")
  end

  test "apple container engine supports local image-store output" do
    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "arm64" })

    assert_equal \
      "container build --platform linux/arm64 -t dhh/app:123-dirty -t dhh/app:latest-dirty --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push("docker", tag_as_dirty: true).join(" ")
  end

  test "apple container engine pushes to a local registry over http" do
    @config[:registry] = { "server" => "localhost:5000" }
    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "amd64" })

    assert_equal \
      "container build --platform linux/amd64 -t localhost:5000/dhh/app:123 -t localhost:5000/dhh/app:latest --label service=\"app\" --file Dockerfile . 2>&1 && container image push --scheme http localhost:5000/dhh/app:123 && container image push --scheme http localhost:5000/dhh/app:latest",
      builder.push.join(" ")
  end

  test "apple container engine pushes to a registry with its configured scheme" do
    @config[:registry] = { "server" => "127.0.0.1:5000", "username" => "dhh", "password" => "secret", "scheme" => "http" }
    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "amd64" })

    assert_equal \
      "container build --platform linux/amd64 -t 127.0.0.1:5000/dhh/app:123 -t 127.0.0.1:5000/dhh/app:latest --label service=\"app\" --file Dockerfile . 2>&1 && container image push --scheme http 127.0.0.1:5000/dhh/app:123 && container image push --scheme http 127.0.0.1:5000/dhh/app:latest",
      builder.push.join(" ")
  end

  test "apple container engine keeps http for a local registry asking for auto" do
    @config[:registry] = { "server" => "localhost:5000", "scheme" => "auto" }
    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "amd64" })

    assert_match "container image push --scheme http localhost:5000/dhh/app:123", builder.push.join(" ")
  end

  test "apple container engine build secrets name their environment source" do
    with_test_secrets("secrets" => "token_a=foo\ntoken_b=bar") do
      FileUtils.touch("Dockerfile")
      builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "arm64", "secrets" => [ "token_a", "token_b" ] })

      assert_equal \
        "--label service=\"app\" --secret id=\"token_a\",env=\"token_a\" --secret id=\"token_b\",env=\"token_b\" --file Dockerfile",
        builder.target.build_options.join(" ")
    end
  end

  test "apple container engine uses its default SSH agent syntax" do
    original_ssh_auth_sock = ENV["SSH_AUTH_SOCK"]
    ENV["SSH_AUTH_SOCK"] = "/tmp/custom-agent.sock"

    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "arm64", "ssh" => "default=$SSH_AUTH_SOCK" })

    assert_equal \
      "--label service=\"app\" --file Dockerfile --ssh default",
      builder.target.build_options.join(" ")
    assert_equal({ "SSH_AUTH_SOCK" => "/tmp/custom-agent.sock" }, builder.push_env)

    literal_builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "arm64", "ssh" => "default=/tmp/literal-agent.sock" })
    assert_equal({ "SSH_AUTH_SOCK" => "/tmp/literal-agent.sock" }, literal_builder.push_env)

    default_builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "arm64", "ssh" => "default" })
    assert_equal({}, default_builder.push_env)
  ensure
    ENV["SSH_AUTH_SOCK"] = original_ssh_auth_sock
  end

  test "apple container engine lifecycle" do
    builder = new_builder_command(builder: { "engine" => "apple-container", "arch" => "arm64" })

    assert_equal "container --version && container system status", builder.ensure_installed.join(" ")
    assert_equal "container builder start", builder.create.join(" ")
    assert_equal "container builder status", builder.inspect_builder.join(" ")
    assert_equal "container builder stop", builder.remove.join(" ")
  end

  test "missing dependencies are reported for the engine in use" do
    builder = new_builder_command

    assert_equal "Docker is not installed locally", builder.install_error("bash: docker: command not found")
    assert_equal "Docker buildx plugin is not installed locally", builder.install_error("no buildx")

    apple_builder = new_builder_command(builder: { "engine" => "apple-container" })

    assert_equal "Apple container is not installed locally", apple_builder.install_error("bash: container: command not found")
    assert_equal "Apple container system service is not running locally", apple_builder.install_error("apiserver is not running")
  end

  test "the local registry speaks the builder's engine" do
    assert_instance_of Kamal::Commands::Registry, new_builder_command.local_registry
    assert_instance_of Kamal::Commands::Registry::AppleContainer,
      new_builder_command(builder: { "engine" => "apple-container" }).local_registry
  end

  test "build with caching" do
    builder = new_builder_command(builder: { "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "hybrid build if remote is set and building multiarch" do
    builder = new_builder_command(builder: { "arch" => [ "amd64", "arm64" ], "remote" => "ssh://app@127.0.0.1", "cache" => { "type" => "gha" } })
    assert_equal "hybrid", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64,linux/arm64 --builder kamal-hybrid-docker-container-ssh---app-127-0-0-1 -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "remote build if remote is set and local disabled" do
    builder = new_builder_command(builder: { "arch" => [ "amd64", "arm64" ], "remote" => "ssh://app@127.0.0.1", "cache" => { "type" => "gha" }, "local" => false })
    assert_equal "remote", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64,linux/arm64 --builder kamal-remote-ssh---app-127-0-0-1 -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "target remote when remote set and arch is non local" do
    builder = new_builder_command(builder: { "arch" => [ "#{remote_arch}" ], "remote" => "ssh://app@host", "cache" => { "type" => "gha" } })
    assert_equal "remote", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/#{remote_arch} --builder kamal-remote-ssh---app-host -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "target local when remote set and arch is local" do
    builder = new_builder_command(builder: { "arch" => [ "#{local_arch}" ], "remote" => "ssh://app@host", "cache" => { "type" => "gha" } })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/#{local_arch} --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --cache-to type=gha --cache-from type=gha --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "target pack when pack is set" do
    builder = new_builder_command(image: "dhh/app", builder: { "arch" => "amd64", "pack" => { "builder" => "heroku/builder:24", "buildpacks" => [ "heroku/ruby", "heroku/procfile" ] } })
    assert_equal "pack", builder.name
    assert_equal \
      "pack build dhh/app --platform linux/amd64 --creation-time now --builder heroku/builder:24 --buildpack heroku/ruby --buildpack heroku/procfile --buildpack paketo-buildpacks/image-labels -t dhh/app:123 -t dhh/app:latest --env BP_IMAGE_LABELS=service=app --path . && docker push dhh/app:123 && docker push dhh/app:latest",
      builder.push.join(" ")
  end

  test "pack build args passed as env" do
    builder = new_builder_command(image: "dhh/app", builder: { "args" => { "a" => 1, "b" => 2 }, "arch" => "amd64", "pack" => { "builder" => "heroku/builder:24", "buildpacks" => [ "heroku/ruby", "heroku/procfile" ] } })

    assert_equal \
      "pack build dhh/app --platform linux/amd64 --creation-time now --builder heroku/builder:24 --buildpack heroku/ruby --buildpack heroku/procfile --buildpack paketo-buildpacks/image-labels -t dhh/app:123 -t dhh/app:latest --env BP_IMAGE_LABELS=service=app --env a=\"1\" --env b=\"2\" --path . && docker push dhh/app:123 && docker push dhh/app:latest",
    builder.push.join(" ")
  end

  test "pack build with no cache" do
    builder = new_builder_command(image: "dhh/app", builder: { "args" => { "a" => 1, "b" => 2 }, "arch" => "amd64", "pack" => { "builder" => "heroku/builder:24", "buildpacks" => [ "heroku/ruby", "heroku/procfile" ] } })

    assert_equal \
      "pack build dhh/app --platform linux/amd64 --creation-time now --builder heroku/builder:24 --buildpack heroku/ruby --buildpack heroku/procfile --buildpack paketo-buildpacks/image-labels -t dhh/app:123 -t dhh/app:latest --clear-cache --env BP_IMAGE_LABELS=service=app --env a=\"1\" --env b=\"2\" --path . && docker push dhh/app:123 && docker push dhh/app:latest",
    builder.push("registry", no_cache: true).join(" ")
  end

  test "pack build secrets as env" do
    with_test_secrets("secrets" => "token_a=foo\ntoken_b=bar") do
      builder = new_builder_command(image: "dhh/app", builder: { "secrets" => [ "token_a", "token_b" ], "arch" => "amd64", "pack" => { "builder" => "heroku/builder:24", "buildpacks" => [ "heroku/ruby", "heroku/procfile" ] } })

      assert_equal \
        "pack build dhh/app --platform linux/amd64 --creation-time now --builder heroku/builder:24 --buildpack heroku/ruby --buildpack heroku/procfile --buildpack paketo-buildpacks/image-labels -t dhh/app:123 -t dhh/app:latest --env BP_IMAGE_LABELS=service=app --env token_a=\"foo\" --env token_b=\"bar\" --path . && docker push dhh/app:123 && docker push dhh/app:latest",
      builder.push.join(" ")
    end
  end

  test "cloud builder" do
    builder = new_builder_command(builder: { "arch" => [ "#{local_arch}" ], "driver" => "cloud docker-org-name/builder-name" })
    assert_equal "cloud", builder.name
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/#{local_arch} --builder cloud-docker-org-name-builder-name -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "--label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile",
      builder.target.build_options.join(" ")
  end

  test "build secrets" do
    with_test_secrets("secrets" => "token_a=foo\ntoken_b=bar") do
      FileUtils.touch("Dockerfile")
      builder = new_builder_command(builder: { "secrets" => [ "token_a", "token_b" ] })
      assert_equal \
        "--label service=\"app\" --secret id=\"token_a\" --secret id=\"token_b\" --file Dockerfile",
        builder.target.build_options.join(" ")
    end
  end

  test "build dockerfile" do
    Pathname.any_instance.expects(:exist?).returns(true).once
    builder = new_builder_command(builder: { "dockerfile" => "Dockerfile.xyz" })
    assert_equal \
      "--label service=\"app\" --file Dockerfile.xyz",
      builder.target.build_options.join(" ")
  end

  test "missing dockerfile" do
    Pathname.any_instance.expects(:exist?).returns(false).once
    builder = new_builder_command(builder: { "dockerfile" => "Dockerfile.xyz" })
    assert_raises(Kamal::Commands::Builder::Base::BuilderError) do
      builder.target.build_options.join(" ")
    end
  end

  test "build target" do
    builder = new_builder_command(builder: { "target" => "prod" })
    assert_equal \
      "--label service=\"app\" --file Dockerfile --target prod",
      builder.target.build_options.join(" ")
  end

  test "build context" do
    builder = new_builder_command(builder: { "context" => ".." })
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile .. 2>&1",
      builder.push.join(" ")
  end

  test "push with build args" do
    builder = new_builder_command(builder: { "args" => { "a" => 1, "b" => 2 } })
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --build-arg a=\"1\" --build-arg b=\"2\" --file Dockerfile . 2>&1",
      builder.push.join(" ")
  end

  test "push with build secrets" do
    with_test_secrets("secrets" => "a=foo\nb=bar") do
      FileUtils.touch("Dockerfile")
      builder = new_builder_command(builder: { "secrets" => [ "a", "b" ] })
      assert_equal \
        "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --secret id=\"a\" --secret id=\"b\" --file Dockerfile . 2>&1",
        builder.push.join(" ")
    end
  end

  test "build with ssh agent socket" do
    builder = new_builder_command(builder: { "ssh" => "default=$SSH_AUTH_SOCK" })

    assert_equal \
      "--label service=\"app\" --file Dockerfile --ssh default=$SSH_AUTH_SOCK",
      builder.target.build_options.join(" ")
  end

  test "validate image" do
    assert_equal "docker inspect -f '{{ .Config.Labels.service }}' dhh/app:123 | grep -x app || (echo \"Image dhh/app:123 is missing the 'service' label\" && exit 1)", new_builder_command.validate_image.join(" ")
  end

  test "context build" do
    builder = new_builder_command(builder: { "context" => "./foo" })
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile ./foo 2>&1",
      builder.push.join(" ")
  end

  test "push with provenance" do
    builder = new_builder_command(builder: { "provenance" => "mode=max" })
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --provenance mode=max . 2>&1",
      builder.push.join(" ")
  end

  test "push with provenance false" do
    builder = new_builder_command(builder: { "provenance" => false })
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --provenance false . 2>&1",
      builder.push.join(" ")
  end

  test "push with sbom" do
    builder = new_builder_command(builder: { "sbom" => true })
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --sbom true . 2>&1",
      builder.push.join(" ")
  end

  test "push with sbom false" do
    builder = new_builder_command(builder: { "sbom" => false })
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --sbom false . 2>&1",
      builder.push.join(" ")
  end

  test "mirror count" do
    command = new_builder_command
    assert_equal "docker info --format '{{index .RegistryConfig.Mirrors 0}}'", command.first_mirror.join(" ")
  end

  test "push with no cache" do
    builder = new_builder_command
    assert_equal \
      "docker buildx build --output=type=registry --platform linux/amd64 --builder kamal-local-docker-container -t dhh/app:123 -t dhh/app:latest --label service=\"app\" --file Dockerfile --no-cache . 2>&1",
      builder.push("registry", no_cache: true).join(" ")
  end

  test "clone path with spaces" do
    command = new_builder_command
    Kamal::Git.stubs(:root).returns("/absolute/path with spaces")
    clone_command = command.clone.join(" ")
    clone_reset_commands = command.clone_reset_steps.map { |a| a.join(" ") }

    assert_match(%r{path\\ with\\ space}, clone_command)
    assert_no_match(%r{path with spaces}, clone_command)

    clone_reset_commands.each do |command|
      assert_match(%r{path\\ with\\ space}, command)
      assert_no_match(%r{path with spaces}, command)
    end
  end

  test "clone reset runs git gc --auto to bound pack growth" do
    command = new_builder_command
    clone_reset_commands = command.clone_reset_steps.map { |a| a.join(" ") }

    assert clone_reset_commands.any? { |c| c.end_with?(" gc --auto --quiet") },
      "expected clone_reset_steps to run git gc --auto, got: #{clone_reset_commands.inspect}"
  end

  test "local builder with local registry includes network host driver option" do
    builder = new_builder_command(registry: { "server" => "localhost:5000" })
    assert_equal "local", builder.name
    assert_equal \
      "docker buildx create --name kamal-local-registry-docker-container --driver=docker-container --driver-opt network=host",
      builder.create.join(" ")
  end

  test "remote builder with local registry" do
    builder = new_builder_command(
      registry: { "server" => "localhost:5000" },
      builder: { "arch" => remote_arch, "remote" => "ssh://app@1.1.1.5" }
    )
    assert_equal "remote", builder.name
    assert_equal \
      "docker context create kamal-remote-ssh---app-1-1-1-5-local-registry-context --description 'kamal-remote-ssh---app-1-1-1-5-local-registry host' --docker 'host=ssh://app@1.1.1.5' ; docker buildx create --name kamal-remote-ssh---app-1-1-1-5-local-registry --driver-opt network=host kamal-remote-ssh---app-1-1-1-5-local-registry-context",
      builder.create.join(" ")
  end

  test "hybrid builder with local registry" do
    builder = new_builder_command(
      registry: { "server" => "localhost:5000" },
      builder: { "arch" => [ "amd64", "arm64" ], "remote" => "ssh://app@1.1.1.5" }
    )
    assert_equal "hybrid", builder.name
    assert_equal \
      "docker buildx create --platform linux/amd64 --name kamal-hybrid-docker-container-ssh---app-1-1-1-5-local-registry --driver=docker-container --driver-opt network=host && docker context create kamal-hybrid-docker-container-ssh---app-1-1-1-5-local-registry-context --description 'kamal-hybrid-docker-container-ssh---app-1-1-1-5-local-registry host' --docker 'host=ssh://app@1.1.1.5' && docker buildx create --platform linux/arm64 --append --name kamal-hybrid-docker-container-ssh---app-1-1-1-5-local-registry --driver-opt network=host kamal-hybrid-docker-container-ssh---app-1-1-1-5-local-registry-context",
      builder.create.join(" ")
  end

  private
    def new_builder_command(additional_config = {})
      Kamal::Configuration.new(@config.deep_merge(additional_config), version: "123").then do |config|
        KAMAL.reset
        KAMAL.stubs(:config).returns(config)
        Kamal::Commands::Builder.new(config)
      end
    end

    def local_arch
      Kamal::Utils.docker_arch
    end

    def remote_arch
      Kamal::Utils.docker_arch == "arm64" ? "amd64" : "arm64"
    end
end
