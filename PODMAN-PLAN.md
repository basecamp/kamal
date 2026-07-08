# Lamak — Podman Support Plan

Lamak is a soft fork of [Kamal](https://github.com/basecamp/kamal) (forked at 2.12.0)
that teaches Kamal to drive **Podman as well as Docker**, selected by a single
config value. Docker stays the untouched default. Lamak tracks upstream closely,
feeds generic improvements back as small PRs, and carries only the Podman-specific
delta that upstream doesn't want.

This document is the plan for the code adjustments. It says *what* we'll change and
*why*, in dependency order.

---

## Design principles (the constraints that keep this sane)

1. **Minimal, quarantined delta.** Divergence debt is the only real enemy of a
   long-lived fork. The smaller our diff against upstream, the cheaper every rebase.
2. **Configuration-driven, not monkey-patched.** One `container_engine` config value
   threaded through a few explicit seams — no runtime class reopening (that's what the
   `kamal_podman` gem does, and it's why it shatters on every Kamal release).
3. **Docker is default and byte-identical.** `container_engine: docker` must produce
   exactly the commands stock Kamal produces. Every existing Kamal test stays green,
   untouched. This is our regression net and our trust with upstream.
4. **Every change independently upstreamable.** Each seam is a small PR that stands on
   its own merits. Each one that lands upstream shrinks our carry.
5. **Podman quirks isolated behind clear methods**, never scattered `if podman`
   conditionals.

---

## The one core change — the engine seam

Today, `lib/kamal/commands/base.rb`:

```ruby
def docker(*args)
  args.compact.unshift :docker
end
```

Every command Kamal builds routes through this single private method, so this one
line is the whole seam. The plan:

- Add `Kamal::Configuration#container_engine` → `:docker` (default) | `:podman`,
  read from `deploy.yml` (`container_engine: podman`), validated to the known set.
- Change `Commands::Base#docker` to `unshift config.container_engine` instead of the
  literal `:docker`. Keep the method **named** `docker` — renaming it would churn
  dozens of call sites and collide with every upstream diff for no functional gain.
  It simply stops being hardcoded to the docker binary.

That single change flips the binary for every command that routes through `#docker`
— which is almost all of them. The exceptions are a handful of places that embed the
literal string `"docker"` inside shell pipe/`while` bodies rather than calling the seam:
`commands/prune.rb` and `commands/app/logging.rb` (see divergence rows 4–5). Those must
be handled explicitly; the seam alone won't reach them. A guard test that greps the
command output for a stray `docker ` under `container_engine: podman` catches any we miss.

The seam is also **the crux upstream PR**: "let the container binary be configurable,
default docker" is defensible to Kamal on its own merits, and if it lands, most of Lamak
evaporates.

---

## The divergence map (where Docker and Podman genuinely differ)

The `kamal_podman` gem already proved points 1–6 work in practice; its override files
are our blueprint. We reimplement them as first-class, config-driven, **tested** code
instead of runtime monkey-patches.

| # | Area | File(s) | The difference | Plan | Upstream? |
|---|------|---------|----------------|------|-----------|
| 1 | Engine binary | `commands/base.rb` (`#docker`, line ~88) | hardcoded `:docker` | configurable `container_engine` seam (above) | **Yes — the crux** |
| 2 | Registry prefix | `configuration.rb#repository` (line 192–193), `configuration/registry.rb` | `repository` joins `registry.server` + image; when `server` is blank the image is unqualified and Docker silently implies `docker.io/`, Podman does not | when podman + no registry server, qualify Docker Hub images with `docker.io/` | Maybe |
| 3 | Proxy image | `configuration/proxy/boot.rb` (`image_default` → `basecamp/kamal-proxy`) | same unqualified-name issue for the proxy image | qualify the proxy image (`docker.io/basecamp/kamal-proxy`) under podman | Maybe |
| 4 | Prune | `commands/prune.rb` | Two problems: `docker image prune --filter` has no Podman equivalent, **and** `tagged_images`/`app_containers`/`active_image_list` embed the literal string `docker` inside `pipe`/`shell` bodies (`while read … do docker rmi`, `docker container ls`) that **bypass the `#docker` seam entirely** — flipping the engine will not touch them | podman branch rewriting the whole method group; route the embedded literals through the engine value too | Podman-only (likely stays) |
| 5 | Logs | `commands/app/logging.rb` | `logs`/`follow_logs` also embed the literal `xargs docker logs …` string, bypassing the seam; podman logs already emit to stderr (the `2>&1` is fine) | podman branch swapping the embedded binary; verify flag parity | Maybe |
| 6 | Builder | `commands/builder/base.rb` (`push`, `info`, `inspect_builder`), `commands/builder.rb` | `docker :buildx, :build/ls/inspect` — no buildx / buildkit in Podman | podman builder target: `podman build` + `podman push`; stub the buildx lifecycle (`create`/`remove`/`inspect` no-op); reject remote / multi-arch / cloud builds under podman | Podman-only |
| 7 | Bootstrap | `cli/server.rb#bootstrap` (orchestration) **and** `commands/docker.rb` (`KAMAL.docker`: `install` via get.docker.com, `in_docker_group?`, `add_to_docker_group`, `create_network`) | the entire install/verify/network path is Docker-specific — not just a version check | check for the configured engine; podman branch skips docker-group logic and the `get.docker.com` install; `network create` is podman-compatible | Maybe |
| 8 | Proxy port caps | `configuration/proxy/boot.rb#default_boot_options` / deploy | rootful Podman doesn't grant `NET_BIND_SERVICE` by default | add the cap for `kamal-proxy` under podman | Podman-only |

---

## Beyond the gem — Lamak's differentiator: rootless + systemd

Neither stock Kamal nor the `kamal_podman` gem handles **true rootless Podman**. This
is Lamak's real reason to exist, and it maps directly onto the rootless Podman + linger
setup already running on this machine (the Cap self-host stack).

- **`<1024` binding.** `kamal-proxy` on 80/443 under rootless Podman needs
  `net.ipv4.ip_unprivileged_port_start` lowered (host prep in `bootstrap`) — beyond the
  rootful `cap-add: NET_BIND_SERVICE` workaround the gem documents.
- **Lifecycle / boot survival.** Generate **Quadlet** `.container` units +
  `loginctl enable-linger` + `systemctl --user daemon-reload` — the Podman-native
  "stay up, survive reboot" path — instead of Docker restart policies.
- Phased *after* rootful engine parity is proven, so we never debug two variables at once.

---

## Config surface

```yaml
# deploy.yml
container_engine: podman   # default: docker
```

One obvious key, validated to `{docker, podman}`. Absent or `docker` ⇒ 100% stock
behavior.

---

## Testing strategy

- **Default-path safety.** Every existing Kamal unit test stays green and untouched —
  proof that `container_engine: docker` is byte-identical to stock.
- **Podman path.** Add fixtures with `container_engine: podman`; assert the emitted
  commands are `podman …`. Mirror the gem's **auto-discovery test**: iterate every
  `Commands::Base` subclass and assert the engine swap holds — this is what catches new
  upstream commands after a rebase.
- **E2E.** Adapt the gem's integration harness (Podman-in-container target VM + a local
  registry, no Docker Hub dependency) for a full deploy under podman — rootful first,
  then rootless.

---

## Upstream PR ladder (each merge shrinks Lamak's delta)

1. **`erb` gemspec declaration** — generic bug: Kamal `require`s `erb` but doesn't
   declare it, so it breaks on Ruby 3.4+ where `erb` is a bundled gem. Send now.
2. **Engine seam** — `container_engine` configurable, default docker. The crux; advocate
   hard. If it lands, Lamak's carry collapses.
3. **Case-by-case** — registry / proxy / logs / bootstrap branches. Offer upstream; keep
   in Lamak if declined.
4. **Podman-only** — prune rewrite, buildx-less builder, rootless/systemd. Likely
   permanent Lamak carry — and that's fine; it's our differentiator.

**Goal state:** with #2 upstream, Lamak shrinks toward "Podman command quirks +
rootless/systemd" only — a fork small enough to rebase in an afternoon.

---

## Fork maintenance workflow

- `upstream` = `basecamp/kamal` (push disabled). Rebase our small delta onto each Kamal
  release; the auto-discovery test flags any breakage immediately.
- Keep every commit mapped to an intended PR, so rebasing and upstreaming stay mechanical
  rather than archaeological.

---

## Milestones

- **M1 — DONE.** Engine seam + docker-default parity: all existing tests green, and
  `container_engine: podman` flips the binary end to end. (`config.container_engine`
  → `Commands::Base#docker`.)
- **M2 — DONE (unit-tested; e2e pending).** Podman divergence branches, all guarded so
  `container_engine: docker` stays byte-identical (776 unit tests green):
  - **Registry/proxy/accessory prefix** — `Configuration#image_reference` qualifies bare
    Docker Hub refs with `docker.io/` under podman; applied at `repository`,
    `Accessory#image`, `Proxy::Boot#image_default`, `Proxy::Run#image`.
  - **Prune** — the embedded `docker` shell literals in `tagged_images`,
    `app_containers`, `active_image_list` now use `config.container_engine`.
  - **Logs** — the `xargs docker logs` literals in `App::Logging` now use the engine.
  - **Bootstrap** — `cli/server.rb#bootstrap` only auto-installs under docker; podman
    reports a manual-install error instead of running `get.docker.com`.
  - **Builder** — `Commands::Builder::Podman` does `podman build` + per-tag `podman push`,
    no-ops the buildx lifecycle, and `Builder#target` rejects remote/cloud/pack/multi-arch.
  - **Proxy port caps** — `--cap-add=net_bind_service` added to the proxy run args under
    podman (rootful <1024 bind).
  - **Buildx check** — `ensure_local_buildx_installed` skips `podman buildx version`
    (Podman has no buildx). *Found by real e2e — unit tests wouldn't have caught it.*
  - **Docker-only container states** — Podman rejects `status=restarting` (app container
    lookup / logs) and `status=dead` (prune); both dropped under podman. *Found by real e2e.*
  - **Real e2e validated (rootless Podman 5.8.2 on this box):** `kamal build push`
    ran for real — `podman login` → `podman build --platform … -t 127.0.0.1:5000/…:<sha>
    -t …:latest … && podman push … && podman push …:latest` → both tags landed in a live
    local registry. The exact `podman run` our lib emits booted the app container, which
    served HTTP. The exact `logs` and `prune` pipelines ran clean against real Podman.
  - Remaining for M2: full deploy *over SSH* (proxy boot + traffic switch) against a
    Podman host — not run here (no sshd on this box; rootless <1024 proxy bind is M3).
- **M3 — DONE (host-prep approach; Quadlet rejected).** Rootless boot-survival, chosen to
  mirror Kamal's existing imperative model rather than rearchitect it into Quadlet units.
  Decisive finding: this box's own rootless stack survives reboot **without** Quadlet — via
  `--restart` policy + `podman-restart.service` + `enable-linger`, exactly the model Kamal
  already emits. So `bootstrap` under podman now **self-detects rootless** (`podman info …
  Rootless`) and, when true, runs `loginctl enable-linger <user>` +
  `systemctl --user enable --now podman-restart.service`. Kamal's deploy model, `--restart
  unless-stopped` policy, and zero-downtime switch are **unchanged** (Podman 5.x's
  `should-start-on-boot=true` filter covers `unless-stopped`, so no policy change needed).
  Validated on real rootless Podman 5.8.2. No new config surface.
  - **Not covered (separate, root-level):** binding 80/443 rootless needs
    `net.ipv4.ip_unprivileged_port_start` ≤ 80 — a host sysctl requiring root, left to the
    operator (rootful uses the M2 `--cap-add=net_bind_service` instead).
- **M3 rejected alternative** — Quadlet `.container` units: Podman-native but conflicts with
  Kamal's new-alongside-old zero-downtime switch and diverges from the proven local
  convention. Higher divergence debt for no functional gain here.
- **M4** — Dogfood: deploy `adamkstinson-site` on Lamak.
- **Ongoing** — upstream PR drip.

---

## Open decisions to confirm

- **Config key name:** `container_engine` (proposed) vs. reusing an existing Kamal
  concept.
- **Rebrand depth:** soft fork (keep the internal `Kamal` namespace, brand externally as
  Lamak) — recommended, and assumed by this plan. Confirm before we touch naming.
- **Distribution:** publish Lamak as a gem with a `lamak` binary, or keep it repo-only
  for now.
