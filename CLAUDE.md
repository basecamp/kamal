# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kamal is a Ruby gem for deploying web applications in Docker containers to remote servers with zero downtime. It orchestrates multi-server deployments using SSHKit for remote command execution and kamal-proxy for traffic management.

## Development Commands

### Running Tests
```bash
# Run all tests
./bin/test

# Run a specific test file
ruby -I test test/cli/main_test.rb

# Run a specific test method
ruby -I test test/cli/main_test.rb -n test_deploy
```

### Building and Installing
```bash
# Install dependencies
bundle install

# Build the gem
gem build kamal.gemspec

# Install locally for testing
gem install kamal-*.gem
```

### Running Kamal Locally
```bash
# Use the development version
./bin/kamal --help

# Or with bundler
bundle exec kamal --help
```

## Architecture Overview

### Core Components

**Commander Pattern (`Kamal::Commander`)**
- Singleton instance accessible via `KAMAL` constant
- Manages configuration, command factories, and SSHKit setup
- Acts as central coordinator for all operations
- Example: `KAMAL.config`, `KAMAL.app`, `KAMAL.builder`

**Configuration System (`Kamal::Configuration`)**
- Loads from `config/deploy.yml` (base) and `config/deploy.{destination}.yml` (overrides)
- Supports ERB preprocessing for dynamic values
- Validates using `Kamal::Configuration::Validator` classes
- Creates specialized config objects: `Registry`, `Builder`, `Proxy`, `Role`, `Accessory`, etc.
- Secrets loaded from `.kamal/secrets` using dotenv format

**Command Pattern (`Kamal::Commands::*`)**
- Commands are **builders**, not executors - they return arrays of shell arguments
- Base class (`Kamal::Commands::Base`) provides helpers: `docker()`, `combine()`, `pipe()`, `shell()`
- Commands never execute directly - SSHKit executes them via `execute(*command_array)`
- Key commands: `App`, `Builder`, `Proxy`, `Accessory`, `Registry`, `Prune`

**CLI Layer (`Kamal::Cli::*`)**
- Thor-based CLI with hierarchical commands
- Base class: `Kamal::Cli::Base` includes `SSHKit::DSL`
- Main commands: `deploy`, `setup`, `rollback`, `init`, `remove`, `upgrade`
- Subcommands: `app`, `build`, `proxy`, `accessory`, `server`, `registry`, `prune`, `lock`, `secrets`

### Deployment Flow

The zero-downtime deployment sequence:

1. **Build Phase**: Build Docker image, push to registry, pull to hosts
2. **Lock Acquisition**: Prevent concurrent deployments
3. **Pre-Deploy Hook**: Run `.kamal/hooks/pre-deploy`
4. **Proxy Bootstrap**: Ensure kamal-proxy is running
5. **Accessory Boot**: Start databases, Redis, etc.
6. **App Boot** (zero-downtime):
   - Primary role boots first (barrier pattern)
   - New container starts
   - kamal-proxy registers new container
   - Health check passes
   - Traffic drains from old container
   - Old container stops
7. **Post-Deploy Hook**: Run `.kamal/hooks/post-deploy`
8. **Lock Release**

### Key Architectural Patterns

**Barrier Pattern** (`Kamal::Cli::Healthcheck::Barrier`)
- Primary role acts as gatekeeper
- Other roles wait until primary passes health check
- Prevents cascading boot failures

**Role-Based Configuration**
- Servers organized into roles (web, workers, etc.)
- Each role has: specific hosts, custom env vars, proxy config, logging settings
- Example: `lib/kamal/configuration/role.rb`

**SSHKit Extensions** (`lib/kamal/sshkit_with_ext.rb`)
- `capture_with_info`, `capture_with_debug` - Capture with logging
- `CompleteAll` - Wait for all hosts, aggregate errors
- `LimitConcurrentStarts` - Throttle concurrent SSH connections

**Hook System**
- Lifecycle hooks in `.kamal/hooks/`
- Available hooks: `pre-connect`, `pre-build`, `pre-deploy`, `post-deploy`, `pre-proxy-reboot`, etc.
- Environment variables passed to hooks (hosts, roles, version)

## Code Organization

```
lib/kamal/
├── cli/              # Thor CLI commands (entry points)
│   ├── app/         # App boot coordination helpers
│   └── *.rb         # Subcommands (build, proxy, accessory, etc.)
├── commands/         # Command builders (return shell command arrays)
│   ├── app/         # App command modules
│   └── builder/     # Builder strategies (local, remote)
├── configuration/    # Configuration objects
│   ├── proxy/       # Proxy-specific config
│   └── validator/   # JSON schema validation
├── secrets/          # Secret loading and adapters
│   └── adapters/    # 1Password, Bitwarden, AWS Secrets Manager, etc.
├── utils/            # Utilities (health, tags, etc.)
├── commander.rb      # Singleton coordinator
└── version.rb        # Version constant

test/
├── cli/              # CLI command tests
├── commands/         # Command builder tests
├── configuration/    # Configuration loading/validation tests
├── integration/      # Docker-based integration tests
├── secrets/          # Secret adapter tests
└── fixtures/         # YAML test configurations
```

## Testing Patterns

**Command Tests**
- Use `SSHKit::Backend::Printer` (no actual execution)
- Assert on generated command arrays
- Example:
  ```ruby
  assert_equal ["docker", "run", "--detach", ...], command.run
  ```

**CLI Tests**
- Inherit from `CliTestCase` (see `test/cli_test_case.rb`)
- Use `run_command("deploy")` to invoke CLI
- Mock SSHKit execution to test command flow

**Configuration Tests**
- Test YAML loading, ERB preprocessing, validation
- Test destination-specific config merging
- Test secret loading and substitution

**Integration Tests**
- Use Docker containers via docker-compose
- Test end-to-end deployment scenarios
- Located in `test/integration/`

## Important Implementation Details

**Container Naming Convention**
- Pattern: `{service}-{role}-{destination}-{version}`
- Example: `myapp-web-production-abc123`
- Labels for filtering: `service`, `role`, `destination`

**Version Management**
- Git-based versioning from `git rev-parse HEAD`
- Detects uncommitted changes (appends `_uncommitted_{hash}`)
- See `lib/kamal/git.rb`

**Environment Variable Merging**
- Three sources: global env, role env, host tags
- Merge order: `config.env` → `role.env` → `tag.env`
- Written to remote env files: `.kamal/apps/{service}/env/roles/{role}.env`
- Mounted as `--env-file` in containers

**Secret Management**
- Common secrets: `.kamal/secrets`
- Destination-specific: `.kamal/secrets-{destination}`
- Inline command substitution: `SECRET=$(command)` executes command
- Adapters for external secret managers (1Password, Bitwarden, AWS, etc.)
- Thread-safe access with mutex protection

**Docker Registry Support**
- Supports Docker Hub, GitHub Container Registry (ghcr.io), AWS ECR, GCP GCR, local registries
- Authentication via `kamal registry login`
- See `lib/kamal/configuration/registry.rb`

## Common Development Workflows

**Adding a New CLI Command**
1. Create command class in `lib/kamal/cli/` inheriting from `Kamal::Cli::Base`
2. Add corresponding command builder in `lib/kamal/commands/`
3. Register in `lib/kamal/commander.rb` if needed
4. Add tests in `test/cli/` and `test/commands/`

**Adding a New Configuration Option**
1. Update relevant config class in `lib/kamal/configuration/`
2. Add validation in `lib/kamal/configuration/validator/`
3. Update fixture YAML files in `test/fixtures/`
4. Add tests in `test/configuration/`

**Adding a New Secret Adapter**
1. Create adapter in `lib/kamal/secrets/adapters/`
2. Implement `fetch(secret_keys, account:, **options)` method
3. Register in `lib/kamal/secrets.rb`
4. Add tests in `test/secrets/`

## Dependencies

- **activesupport** (>= 7.0) - Rails utilities
- **sshkit** (>= 1.23.0) - Remote command execution
- **thor** (~> 1.3) - CLI framework
- **dotenv** (~> 3.1) - Environment variable loading
- **zeitwerk** (>= 2.6.18) - Code loading

## Testing Requirements

- Ruby 3.2+ required
- Run `bundle install` to install dependencies
- All tests must pass before submitting PRs: `./bin/test`
- Add tests for new features and bug fixes
- Integration tests require Docker

## Documentation

- Main documentation: https://kamal-deploy.org
- Installation: https://kamal-deploy.org/docs/installation
- Configuration: https://kamal-deploy.org/docs/configuration
- Commands: https://kamal-deploy.org/docs/commands
- Documentation contributions: https://github.com/basecamp/kamal-site
