# Poiesis

## Project Purpose

Poiesis is a Docker image running an [OpenClaw](https://docs.openclaw.ai) gateway that monitors a blog for posts articulating software project concepts and scaffolds private GitHub repositories from them for review. It is the second stage in a pipeline with [Aletheia](https://github.com/svo/aletheia): Aletheia unconceals concepts as blog posts; Poiesis brings them forth as structure.

Named after the Greek concept of bringing-forth — making something present that wasn't before.

## Architecture

### Single-Container Service

Poiesis is one Debian-slim container. Inside it, OpenClaw is the primary gateway and delegates scaffolding work to Claude Code. There are no microservices and no frontend — the container's only exposed port is 3000, for OpenClaw's interface.

Cron drives behaviour: on each scheduled tick (`POIESIS_CRON_SCHEDULE`) the agent inspects `POIESIS_BLOG_URL` for new posts that articulate software project concepts, and for each new concept creates a private GitHub repo under `POIESIS_GITHUB_OWNER` and scaffolds it via Claude Code.

### Image Family

Three Packer images live under `infrastructure/packer/`:

| Image | Purpose |
|---|---|
| `svanosselaer/poiesis-builder` | Build environment used by `./build.sh` to produce the other images |
| `svanosselaer/poiesis-development` | Dev-container image referenced by the `Vagrantfile` |
| `svanosselaer/poiesis-service` | Runtime image users deploy |

Each is provisioned by a matching Ansible playbook under `infrastructure/ansible/`:

- `playbook-builder.yml` → `poiesis-builder`
- `playbook-development.yml` → `poiesis-development`
- `playbook-service.yml` → `poiesis-service`

Shared roles live in `infrastructure/ansible/roles/`. Notable ones: `openclaw`, `claude-code`, `claude-code-service` (service-specific workspace bootstrap and auth handling), plus tooling roles (`github-cli`, `python`, `pipx`, `pyscaffold`, `tox`, `semgrep`, `shellcheck`, `ansible-lint`, `docker`, `git`, `node`, `packer`).

### Workspace Files

On startup the service entrypoint generates OpenClaw workspace files at `~/.openclaw/workspace/` from `POIESIS_*` environment variables and sets `agent.skipBootstrap: true`:

| File | Role |
|---|---|
| `IDENTITY.md` | Name, vibe, emoji |
| `SOUL.md` | Persona, tone, boundaries for a project-scaffolding agent |
| `AGENTS.md` | Operating instructions — blog monitoring, concept extraction, scaffolding, schedule |
| `USER.md` | GitHub owner and timezone |

These are injected at the start of every OpenClaw session, so the agent knows how to behave without re-bootstrapping.

## Development

### Dev Container

The `Vagrantfile` provisions a dev container from `svanosselaer/poiesis-development:latest` using Vagrant's Docker provider. It mounts the host Docker socket so builds from inside the VM use the host daemon. `vagrant ssh` drops you into `/vagrant`. Ansible re-provisions on every `vagrant up`, so role edits land without a rebuild.

### Build & Release

Root scripts wrap the builder image:

```bash
./build.sh service arm64    # build poiesis-service for arm64
./build.sh service amd64
./push.sh service arm64     # push per-arch tag
./push.sh service amd64
./create-latest.sh service  # create and push the multi-arch :latest manifest
```

Substitute `builder` or `development` for `service` to build the other images. `bin/create-image` inside the builder image orchestrates Packer.

### Environment

Required at service startup: every `POIESIS_*` variable listed in `README.md`, plus `GITHUB_TOKEN` (validated separately) and `ANTHROPIC_API_KEY`. The container fails fast if any are missing. Claude Code can optionally use `CLAUDE_CODE_OAUTH_TOKEN` (a long-lived subscription token) instead of the API key.

Telegram and Slack integrations are optional — see `README.md`. The Slack app manifest lives at `infrastructure/slack-app-manifest.json`.

### Linting & Validation

The development image ships `shellcheck`, `ansible-lint`, `semgrep`, and `tox`. Python tooling (`pipx`, `pyscaffold`) is installed so scaffolded Python projects can be built end-to-end from inside the dev container when validating scaffolding changes.

## Scaffolding Targets

Poiesis creates **new external repos** under `POIESIS_GITHUB_OWNER` — it does not add them as submodules of this repo. Scaffolded outputs stand alone and are iterated on independently; changes to *how* scaffolding works happen here.

## What Not to Build

- Do not turn this into a multi-service platform — one container, one OpenClaw gateway.
- Do not hard-code agent behaviour in entrypoint scripts or roles; tune it through the generated `IDENTITY.md` / `SOUL.md` / `AGENTS.md` / `USER.md` instead.
- Do not persist service state outside `/root/.openclaw` — the volume is the only durable surface.
- Do not couple Poiesis to a specific scaffolded project; scaffolded repos live elsewhere and must not be referenced as submodules or build-time dependencies here.
