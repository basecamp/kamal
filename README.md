# Lamak: Kamal that also speaks Podman

Lamak is a soft fork of [Kamal](https://github.com/basecamp/kamal) that teaches it to drive
**Podman as well as Docker**, chosen by a single config value. Everything else is Kamal:
same commands, same `deploy.yml`, same zero-downtime deploys via
[kamal-proxy](https://github.com/basecamp/kamal-proxy). Docker stays the default and is
byte-identical to upstream — the entire Podman path is gated behind one setting, so
`container_engine: docker` (or omitting it) is exactly stock Kamal.

The name is `kamal` reversed. Internally the gem, the `kamal` binary, and the `Kamal`
namespace are unchanged, so the fork tracks upstream cheaply.

## Why this exists

Podman runs containers **rootless** and **daemonless** — no root-owned daemon, each app
in an unprivileged user account. That's a better fit for small, self-hosted, single-tenant
deployments than Docker's root daemon. Kamal only speaks Docker; Lamak lets you keep Kamal's
whole workflow while running Podman underneath, including a true rootless setup that survives
reboots.

## Quick start

**1. Point your app at Lamak** instead of the `kamal` gem. In your `Gemfile`:

```ruby
gem "kamal", github: "adamkstinson/lamak", branch: "podman-support"
```

**2. Set the engine** in `config/deploy.yml`:

```yaml
container_engine: podman   # default: docker
```

**3. Deploy as normal.** Every command works unchanged:

```bash
kamal server bootstrap   # prepares the host (see below)
kamal setup              # first deploy
kamal deploy             # subsequent deploys
kamal app logs -f
kamal prune all
```

That's the whole difference. The engine flips to `podman` everywhere at once.

## What the target host needs

- **Podman installed.** Unlike Docker, Lamak will not auto-install Podman (there's no
  universal installer) — `bootstrap` checks for it and, if missing, tells you to install it
  for your distro. Everything downstream is automatic.
- **Rootless hosts get boot-survival for free.** `kamal server bootstrap` detects rootless
  Podman and enables `linger` + `podman-restart.service`, the rootless analog of the Docker
  daemon restarting your containers after a reboot. Kamal's normal `--restart` policy is
  untouched.
- **Binding 80/443 rootless is the one manual step.** Rootless Podman can't bind ports below
  1024 by default. Either:
  - lower it host-wide (root): `sysctl -w net.ipv4.ip_unprivileged_port_start=80` (persist in
    `/etc/sysctl.d/`), **or**
  - run **rootful** Podman, where Lamak adds `--cap-add=net_bind_service` to the proxy for you.

## How Podman differs (Lamak handles these automatically)

- **Image names** — bare Docker Hub references (`nginx`, `basecamp/kamal-proxy`, your app on
  Docker Hub) are qualified with `docker.io/` under Podman, which doesn't assume it the way
  Docker does. Registries with an explicit host are left alone.
- **Builds** — Podman has no buildx/BuildKit, so Lamak uses `podman build` + `podman push`.
  This means builds are **local and single-architecture only**: remote, cloud, pack, and
  multi-arch builders are rejected with a clear error under Podman. Build your image on a host
  matching your servers' architecture.
- **Prune, logs, container filters** — rewritten where Podman's CLI differs from Docker's
  (e.g. Podman has no `restarting`/`dead` container states).

## Status & limitations

Command generation is unit-tested (Docker output is guaranteed identical to upstream) and has
been exercised end-to-end against real rootless Podman — build, push, container boot, and a
live kamal-proxy traffic switch. Not yet covered: a full SSH-driven deploy in CI. Treat your
first real Podman deploy as a shakedown.

See [`PODMAN-PLAN.md`](PODMAN-PLAN.md) for the design, the divergence map, and the rationale
behind each choice.

## Upstream

Lamak tracks `basecamp/kamal` and aims to feed generic improvements back as small PRs. For
Kamal's own documentation see [kamal-deploy.org](https://kamal-deploy.org).

## License

Released under the [MIT License](https://opensource.org/licenses/MIT), same as Kamal.
