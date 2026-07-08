# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is **Lamak**, a soft fork of [Kamal](https://github.com/basecamp/kamal) (forked at
2.12.0) that teaches Kamal to drive **Podman as well as Docker**, selected by a single
`container_engine` config value. Docker stays the untouched, byte-identical default. The
internal namespace, gem name, and binary are still `Kamal`/`kamal` — the fork is
deliberately soft so rebasing onto upstream stays cheap.

**Read `PODMAN-PLAN.md` before making changes.** It defines the fork's governing
constraints, which override normal "just make it work" instincts:

- **Keep the diff against upstream minimal and quarantined.** Divergence debt is the
  enemy. Prefer one config value threaded through explicit seams over scattered
  `if podman` conditionals or runtime monkey-patching.
- **`container_engine: docker` must stay byte-identical to stock Kamal.** Every existing
  test must pass untouched — that is the regression net.
- The engine seam is `Kamal::Commands::Base#docker` (`lib/kamal/commands/base.rb`), the
  single private method every container command routes through. A few commands embed the
  literal string `"docker"` inside shell pipe bodies (`commands/prune.rb`,
  `commands/app/logging.rb`) and bypass the seam — those need explicit handling.

## Commands

```bash
bundle                       # install dependencies (Ruby 3.2+)

bin/test                     # run ALL tests (unit + integration)
bin/test test/commands       # run a directory of unit tests
bin/test test/commands/app_test.rb        # run one file
bin/test test/commands/app_test.rb:42     # run the test at a line (Rails line filtering)
bin/test -n "/deploy/"       # run tests matching a name pattern

bundle exec rubocop --parallel            # lint (rubocop-rails-omakase)
BUNDLE_ONLY=rubocop bundle exec rubocop   # how CI runs it

bin/kamal <command>          # run the CLI locally
bin/docs <kamal-site-repo>   # regenerate website docs from configuration/docs/*.yml
```

**Integration tests are part of `bin/test` and require a running Docker daemon.** They
live in `test/integration/` and stand up a full Docker Compose stack (a `deployer`
container plus fake target VMs, a load balancer, and a local registry) to run real
deploys against — see `test/integration/docker-compose.yml`. Useful env vars when they
fail: `DEBUG=1` (show compose output), `DEBUG_CONTAINER_LOGS=1` (dump container logs on
failure), `VERBOSE=1` (backtraces + logging), and `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN`
(avoid Docker Hub rate limits). To run only unit tests, pass a non-integration path to
`bin/test`. CI runs the full suite across Ruby 3.2–4.0 and against `gemfiles/rails_edge.gemfile`.

## Architecture

Kamal is an SSH-based container deploy tool. The codebase has a strict two-layer split
that is essential to understand:

- **CLI layer** (`lib/kamal/cli/*`) — Thor commands that *orchestrate*. They open SSHKit
  sessions (`on(hosts) { execute ... }`) and decide what runs where. `bin/kamal` boots
  `Kamal::Cli::Main`, which wires subcommands (`app`, `build`, `proxy`, `prune`,
  `accessory`, `registry`, `secrets`, `server`, `lock`).
- **Commands layer** (`lib/kamal/commands/*`) — pure command *builders*. Each method
  returns an array of shell tokens (or a combined string) and **executes nothing**.
  Helpers in `Commands::Base` (`combine`, `chain`, `pipe`, `append`, `any`, `shell`)
  compose them. Because commands are just data, tests assert on the emitted strings using
  `SSHKit::Backend::Printer` (configured in `test/test_helper.rb`) rather than running
  anything.

**`KAMAL` is the global `Kamal::Commander` singleton** (`lib/kamal/commander.rb`) that
ties the layers together. It lazily builds and memoizes the configuration and the command
builders, and exposes them as `KAMAL.config`, `KAMAL.docker`, `KAMAL.app`, `KAMAL.proxy`,
`KAMAL.builder`, `KAMAL.auditor`, `KAMAL.server`, etc. It also tracks the deploy lock and
the `--hosts`/`--roles` filtering (`specific_hosts`, `specific_roles`).

**Configuration** (`lib/kamal/configuration/*`) parses `config/deploy.yml` (plus
destination overlays and secrets) into an object graph — `registry`, `builder`, `proxy`,
`servers`, `roles`, `ssh`, `env`, `accessories`, `boot`, `logging`. Each sub-config has:
a **validator** in `configuration/validator/*` (schema/rules), and a **docs source** in
`configuration/docs/*.yml` that `bin/docs` transforms into the kamal-deploy.org website.
When you add or change a config key, update the matching validator and docs yml.

**Deploy model:** a `kamal-proxy` container (image `basecamp/kamal-proxy`) fronts the app
containers and switches traffic between old and new versions for zero-downtime deploys.
Apps run across multiple hosts grouped into `roles`; supporting services (db, redis,
search) run as `accessories`. Images are produced by a **builder target** chosen from
`local`, `remote`, `hybrid`, `pack`, or `cloud` (`commands/builder/*`), dispatched by
`Commands::Builder#target`.

Autoloading is via **Zeitwerk** (`lib/kamal.rb`), which eager-loads the `Kamal::Cli`
namespace so all Thor commands are registered at boot.
