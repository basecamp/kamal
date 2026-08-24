class Kamal::Commands::Builder::AppleContainer < Kamal::Commands::Builder::Base
  def create
    apple_container :builder, :start
  end

  def remove
    apple_container :builder, :stop
  end

  def ensure_installed
    combine \
      apple_container("--version"),
      apple_container(:system, :status)
  end

  def install_error(output)
    output.match?(/command not found/) ?
      "Apple container is not installed locally" :
      "Apple container system service is not running locally"
  end

  def local_registry
    Kamal::Commands::Registry::AppleContainer.new(config)
  end

  def info
    apple_container :builder, :status
  end
  alias_method :inspect_builder, :info

  def build_check_commands(dockerfile:, tag:)
    { build: [ "container", "build", "--tag", tag, "--file", dockerfile, "." ],
      run: [ "container", "run", "--rm", tag ] }
  end

  def push(export_action = "registry", tag_as_dirty: false, no_cache: false)
    build = apple_container :build,
      *platform_options(arches),
      *build_tag_options(tag_as_dirty: tag_as_dirty),
      *build_options,
      *([ "--no-cache" ] if no_cache),
      build_context,
      "2>&1"

    case export_action
    when "registry"
      combine build, *build_tag_names(tag_as_dirty: tag_as_dirty).map { |tag|
        apple_container(:image, :push, *registry_scheme_options, tag)
      }
    when "docker"
      build
    else
      raise BuilderError, "The apple-container engine only supports registry and local image-store output"
    end
  end

  def build_options
    [ *build_labels, *build_args, *build_secrets, *build_dockerfile, *build_target, *build_ssh ]
  end

  # The push commands carry no --platform, so `container` would take one from
  # CONTAINER_DEFAULT_PLATFORM and narrow the push to it. Empty reads as unset.
  def push_env
    socket = ssh_socket

    { "CONTAINER_DEFAULT_PLATFORM" => "" }.tap do |env|
      env["SSH_AUTH_SOCK"] = socket if socket
    end
  end

  private
    def build_ssh
      [ "--ssh", "default" ] if ssh.present?
    end

    def build_secrets
      secrets.keys.flat_map do |secret|
        [ "--secret", "id=#{Kamal::Utils.escape_shell_value(secret)},env=#{Kamal::Utils.escape_shell_value(secret)}" ]
      end
    end

    def registry_scheme_options
      [ "--scheme", registry_config.scheme ] if registry_config.scheme.present?
    end

    def ssh_socket
      source = ssh&.split("=", 2)&.[](1)

      case source
      when /\A\$(\w+)\z/
        ENV[Regexp.last_match(1)]
      when /\A\$\{(\w+)\}\z/
        ENV[Regexp.last_match(1)]
      else
        source
      end
    end

    def platform_options(arches)
      arches.flat_map { |arch| [ "--platform", "linux/#{arch}" ] }
    end
end
