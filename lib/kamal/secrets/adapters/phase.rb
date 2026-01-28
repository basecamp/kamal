class Kamal::Secrets::Adapters::Phase < Kamal::Secrets::Adapters::Base
  def requires_account?
    true  # Account is used for app name
  end

  private
    def login(account)
      # Check if already authenticated
      unless authenticated?
        # Interactive auth required
        `phase auth`.tap do
          raise RuntimeError, "Failed to authenticate with Phase. Run 'phase auth' to login" unless $?.success?
        end
      end
      nil
    end

    def authenticated?
      `phase users whoami 2> /dev/null`
      $?.success?
    end

    def fetch_secrets(secrets, from:, account:, session:)
      # Parse 'from' parameter to extract environment and path
      # Format can be: "production" or "production/path/to/secrets"
      env, path = parse_from(from)

      if secrets.empty?
        fetch_all_secrets(env: env, path: path, app: account)
      else
        fetch_specified_secrets(secrets, env: env, path: path, app: account)
      end
    end

    def fetch_all_secrets(env:, path:, app:)
      args = build_command_args("secrets", "export", env: env, path: path, app: app)
      args += ["--format", "json"]

      cmd = args.join(" ")
      output = `#{cmd}`
      raise RuntimeError, "Failed to fetch secrets from Phase. Ensure app '#{app}' exists and you have access" unless $?.success?

      # Parse JSON output from phase secrets export
      secrets_data = JSON.parse(output)

      # Transform to expected format
      {}.tap do |results|
        secrets_data.each do |key, value|
          # Build full path for the key
          full_key = build_result_key(key, env: env, path: path)
          results[full_key] = value
        end
      end
    rescue JSON::ParserError => e
      raise RuntimeError, "Failed to parse Phase CLI output: #{e.message}"
    end

    def fetch_specified_secrets(secrets, env:, path:, app:)
      {}.tap do |results|
        secrets.each do |secret_key|
          args = build_command_args("secrets", "get", secret_key, env: env, path: path, app: app)
          cmd = args.join(" ")

          output = `#{cmd}`
          raise RuntimeError, "Could not read '#{secret_key}' from Phase app '#{app}'" unless $?.success?

          # Parse JSON output from phase secrets get
          secret_data = JSON.parse(output)

          # Build full path for the result key
          full_key = build_result_key(secret_key, env: env, path: path)
          results[full_key] = secret_data["value"]
        end
      end
    rescue JSON::ParserError => e
      raise RuntimeError, "Failed to parse Phase CLI output for secret: #{e.message}"
    end

    def parse_from(from)
      return ["development", "/"] if from.blank?

      parts = from.split("/", 2)
      env = parts[0]
      path = parts[1] ? "/#{parts[1]}" : "/"

      [env, path]
    end

    def build_result_key(secret_key, env:, path:)
      # Build hierarchical key: environment/path/secret_key
      components = [env]
      components << path.delete_prefix("/") if path != "/"
      components << secret_key
      components.join("/")
    end

    def build_command_args(*command_parts, env:, path:, app:)
      args = ["phase"] + command_parts
      args += ["--env", env.shellescape] if env
      args += ["--app", app.shellescape] if app
      args += ["--path", path.shellescape] if path && path != "/"
      args
    end

    def check_dependencies!
      raise RuntimeError, "Phase CLI is not installed. Install it from https://docs.phase.dev/cli/install" unless cli_installed?
    end

    def cli_installed?
      `phase --version 2> /dev/null`
      $?.success?
    end
end
