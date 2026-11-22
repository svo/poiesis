<p align="center">
  <img src="icon.png" alt="Poiesis" width="128">
</p>

# Poiesis

[![Build Development](https://github.com/svo/poiesis/actions/workflows/development.yml/badge.svg)](https://github.com/svo/poiesis/actions/workflows/development.yml)
[![Build Builder](https://github.com/svo/poiesis/actions/workflows/builder.yml/badge.svg)](https://github.com/svo/poiesis/actions/workflows/builder.yml)
[![Build Service](https://github.com/svo/poiesis/actions/workflows/service.yml/badge.svg)](https://github.com/svo/poiesis/actions/workflows/service.yml)
[![Checks](https://github.com/svo/poiesis/actions/workflows/checks.yml/badge.svg)](https://github.com/svo/poiesis/actions/workflows/checks.yml)

Docker image running an [OpenClaw](https://docs.openclaw.ai) gateway that monitors a blog for posts articulating software project concepts and scaffolds private GitHub repositories from them for review.

Poiesis is the second stage in a pipeline with [Aletheia](https://github.com/svo/aletheia):

1. **Aletheia** identifies and articulates concepts — unconceals them as blog posts
2. **Poiesis** receives those posts and brings them forth as structure — scaffolded GitHub projects

Named after the Greek concept of bringing-forth — the act of making something present that wasn't before.

## Prerequisites

* `vagrant`
* `ansible`
* `colima`
* `docker`
- An Anthropic API key
- A GitHub personal access token with `repo` scope
- A [Brave Search API](https://brave.com/search/api/) key (for web search)

## Building

```bash
# Build for a specific architecture
./build.sh service arm64
./build.sh service amd64

# Push
./push.sh service arm64
./push.sh service amd64

# Create and push multi-arch manifest
./create-latest.sh service
```

## Pinned Versions

| What | Where | Currently |
|---|---|---|
| OpenClaw (service image) | `roles/openclaw/defaults/main.yml` → `openclaw_version` | `2026.9.37` |
| Claude Code (service image) | `roles/claude-code-service/defaults/main.yml` → `claude_code_version` | `2.1.330` |
| Node.js major (all three images) | `roles/node/defaults/main.yml` → `node_major` + `node_minimum_version` | `26`, at least `26.12.1` |

OpenClaw used to install with `state: latest`, so a rebuild that changed nothing in this repository could install a different gateway. OpenClaw checks the Node version at startup and exits on one it does not support: 2026.9.37 wants `>=24.22.1 <25 || >=26.12.1`, and the images used to install Node 22.

### Bumping OpenClaw

```bash
npm view openclaw dist-tags                # what is published
npm view openclaw@<version> engines        # the Node it needs
```

Set `openclaw_version`. If the release needs a newer Node, set `node_major` and `node_minimum_version`, and add the major being left to `node_retired_majors` so a machine provisioned again drops its repository. The build fails if the Node it installed is older than `node_minimum_version` or outside that major. A machine that already has Node keeps it when the repository changes; the check then fails the provisioning and says to run `apt-get install nodejs`. The Vagrant dev container hits this on `vagrant up` until `poiesis-development` is rebuilt.

Check that the model ids in `entrypoint.sh` are in the new release's catalog (see [Models](#models)) before landing the bump.

### Bumping Claude Code

Claude Code used to install unpinned, so two builds of the same commit could carry different versions, and the prompts and skills it runs could behave differently in each. A bump is now a deliberate change, like an OpenClaw bump:

```bash
npm view @anthropic-ai/claude-code dist-tags      # what is published
```

Set `claude_code_version`, rebuild the service image, and check that `claude --version` in it prints the new version. Then run the pipeline skills against the new version before landing the bump: in the image, with credentials, ask Claude Code headlessly (`claude -p … --output-format stream-json`) to run the `purge-template` skill on a copy of a `python-sprint-zero` checkout, and confirm the transcript shows the skill loading, with no refusal, and `poiesis-purge-check` passing. The development image is not pinned; it is for people, and only the service image runs unattended.

## Running

```bash
docker run -d \
  --name poiesis \
  --restart unless-stopped \
  --pull always \
  -e ANTHROPIC_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e BRAVE_API_KEY="your-brave-api-key" \
  -e TELEGRAM_BOT_TOKEN="your-telegram-bot-token" \
  -e POIESIS_BLOG_URL="https://www.qual.is/blog" \
  -e POIESIS_GITHUB_OWNER="svo" \
  -e POIESIS_IMAGE_NAMESPACE="svanosselaer" \
  -e POIESIS_CRON_SCHEDULE="0 8 * * 1" \
  -e POIESIS_TIMEZONE="Australia/Melbourne" \
  -v /opt/poiesis/data:/root/.openclaw \
  -p 127.0.0.1:3000:3000 \
  svanosselaer/poiesis-service:latest
```

On first run, the entrypoint automatically configures OpenClaw via non-interactive onboarding and sets up web search, web fetch, and messaging access. Configuration is persisted to the volume at `/root/.openclaw` so subsequent starts skip onboarding. Every start runs `openclaw doctor --fix` before the gateway — see [Doctor Runs on Every Start](#doctor-runs-on-every-start).

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key for OpenClaw (and Claude Code if no subscription token is set) |
| `CLAUDE_CODE_OAUTH_TOKEN` | No | Claude subscription OAuth token for Claude Code — if set, Claude Code uses the subscription instead of the API key |
| `GITHUB_TOKEN` | Yes | GitHub personal access token with `repo` scope for creating repositories |
| `BRAVE_API_KEY` | No | [Brave Search API](https://brave.com/search/api/) key for web search |
| `FIRECRAWL_API_KEY` | No | [Firecrawl](https://firecrawl.dev) API key for enhanced web scraping |
| `TELEGRAM_BOT_TOKEN` | No | Telegram bot token from @BotFather |
| `TELEGRAM_ALLOW_FROM` | With `TELEGRAM_BOT_TOKEN` | Comma-separated Telegram user IDs to allow |
| `SLACK_BOT_TOKEN` | No | Slack bot token (`xoxb-...`) from the Slack app settings |
| `SLACK_APP_TOKEN` | With `SLACK_BOT_TOKEN` | Slack app-level token (`xapp-...`) with `connections:write` scope |
| `POIESIS_BLOG_URL` | Yes | Blog URL to monitor for software project concepts |
| `POIESIS_GITHUB_OWNER` | Yes | GitHub user or organisation to create repositories under |
| `POIESIS_CRON_SCHEDULE` | Yes | Cron expression for blog monitoring runs |
| `POIESIS_TIMEZONE` | Yes | Timezone for scheduling |
| `POIESIS_HOST_PORT_PREFIX` | No | Single digit `1`–`9` (default `3`) placed in front of every guest port to make the host ports in a scaffolded project's Vagrantfile: guest `8001` becomes host `38001`. Any other value logs a warning and falls back to `3` |
| `POIESIS_IMAGE_NAMESPACE` | No | Registry namespace for the image names a scaffold generates (`<namespace>/<project>-<service>-service`, in each service's Packer `docker-tag` and in the Vagrantfile). Defaults to `POIESIS_GITHUB_OWNER` in lower case. Must be lowercase letters and digits separated by single `.`, `_` or `-`; the container exits on startup, naming the variable, if it is not. Set it when your registry namespace differs from your GitHub owner (`svo` on GitHub, `svanosselaer` on Docker Hub) |

Claude Code, which does the scaffolding, runs as the `claude` user and cannot read the workspace files under `/root`. The scheduled cycle command in `AGENTS.md` passes it `POIESIS_BLOG_URL`, `POIESIS_GITHUB_OWNER`, `POIESIS_HOST_PORT_PREFIX` and `POIESIS_IMAGE_NAMESPACE` in its environment.

## Telegram Integration

Connect Poiesis to Telegram so you can chat with your assistant directly from the Telegram app.

### Setup

1. Open Telegram and start a chat with [@BotFather](https://t.me/BotFather)
2. Send `/newbot` and follow the prompts to name your bot
3. Save the bot token that BotFather returns
4. Pass it as an environment variable when running the container:

```bash
docker run -d \
  --name poiesis \
  --restart unless-stopped \
  -e ANTHROPIC_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e TELEGRAM_BOT_TOKEN="your-telegram-bot-token" \
  -e TELEGRAM_ALLOW_FROM="your-telegram-user-id" \
  -v /opt/poiesis/data:/root/.openclaw \
  -p 127.0.0.1:3000:3000 \
  svanosselaer/poiesis-service:latest
```

On startup, the entrypoint automatically configures the Telegram channel in OpenClaw with group chats set to require `@mention`. When `TELEGRAM_ALLOW_FROM` is set, the DM policy is `allowlist` — only the listed Telegram user IDs can message the bot. Without it, the policy falls back to `pairing` (unknown users get a pairing code for the owner to approve).

To find your Telegram user ID, message the bot without `TELEGRAM_ALLOW_FROM` set — the pairing prompt will show it.

## Slack Integration

Connect Poiesis to Slack so you can chat with your assistant from any Slack workspace.

### Setup

1. Create a Slack app at https://api.slack.com/apps using the manifest in [`infrastructure/slack-app-manifest.json`](infrastructure/slack-app-manifest.json) — this configures Socket Mode, bot scopes, and event subscriptions automatically
2. Go to Basic Information > App-Level Tokens > generate a token with `connections:write` scope — this is your `SLACK_APP_TOKEN` (`xapp-...`)
3. Install the app to the workspace and go to OAuth & Permissions to copy the Bot User OAuth Token — this is your `SLACK_BOT_TOKEN` (`xoxb-...`)
4. Pass both tokens as environment variables:

```bash
docker run -d \
  --name poiesis \
  --restart unless-stopped \
  -e ANTHROPIC_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e SLACK_BOT_TOKEN="xoxb-your-slack-bot-token" \
  -e SLACK_APP_TOKEN="xapp-your-slack-app-token" \
  -v /opt/poiesis/data:/root/.openclaw \
  -p 127.0.0.1:3000:3000 \
  svanosselaer/poiesis-service:latest
```

On startup, the entrypoint configures the Slack channel in socket mode and sets `plugins.entries.slack.enabled: true`. Slack is an external plugin that OpenClaw installs into the volume on first use, and it will not load an external plugin it has not been told to trust. Without that key the gateway logs `external plugin "slack" is installed without explicit trust` and does not start the channel. `openclaw doctor --fix` adds the key, but it runs before the channel is written, so on its own it would leave the first start that configures Slack without one.

## Using a Claude Subscription for Claude Code

By default, Claude Code uses the same `ANTHROPIC_API_KEY` as OpenClaw. If you have a Claude Pro or Max subscription, you can configure Claude Code to use it instead — this keeps API key costs for OpenClaw only, while Claude Code's usage is covered by the subscription.

1. Start the container without `CLAUDE_CODE_OAUTH_TOKEN`
2. Run `docker exec -it poiesis claude setup-token` — it will display a URL
3. Open the URL in your browser and complete the authentication to generate a long-lived OAuth token (valid for 1 year)
4. Restart the container with the token as an environment variable:

```bash
docker run -d \
  --name poiesis \
  --restart unless-stopped \
  -e ANTHROPIC_API_KEY="your-api-key" \
  -e CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..." \
  -e GITHUB_TOKEN="your-github-token" \
  -e POIESIS_BLOG_URL="https://www.qual.is/blog" \
  -e POIESIS_GITHUB_OWNER="svo" \
  -e POIESIS_CRON_SCHEDULE="0 8 * * 1" \
  -e POIESIS_TIMEZONE="Australia/Melbourne" \
  -v /opt/poiesis/data:/root/.openclaw \
  -p 127.0.0.1:3000:3000 \
  svanosselaer/poiesis-service:latest
```

When `CLAUDE_CODE_OAUTH_TOKEN` is set, Claude Code uses the subscription automatically. OpenClaw continues to use `ANTHROPIC_API_KEY`. The token is valid for 1 year.

## Workspace Instructions

On startup, the entrypoint generates OpenClaw workspace files at `~/.openclaw/workspace/` using the `POIESIS_*` environment variables and sets `agent.skipBootstrap: true` so OpenClaw uses the pre-seeded files directly:

| File | Content |
|---|---|
| `IDENTITY.md` | Name, vibe, and emoji |
| `SOUL.md` | Persona, tone, and boundaries for a project-scaffolding agent |
| `AGENTS.md` | Operating instructions — blog monitoring, concept extraction, scaffolding process, and schedule |
| `USER.md` | GitHub owner and timezone |

These files are injected into the agent's context at the start of every session, so Poiesis knows how to identify software concepts and scaffold projects immediately.

The `POIESIS_*` variables marked required above must be set — the container will fail on startup if any are missing. `GITHUB_TOKEN` is also required and validated separately.

## Models

The entrypoint writes these on every start. They are the gateway's models only: the scaffolding itself is done by Claude Code, which chooses its own.

| Work | Model | Key |
|---|---|---|
| Scheduled cycles, chat, and the tasks they start | `anthropic/claude-opus-5-5` | `agents.defaults.model` |
| Heartbeat | `anthropic/claude-haiku-5-5` | `agents.defaults.heartbeat.model` |
| Compaction | `anthropic/claude-haiku-5-5` | `agents.defaults.compaction.model` |
| Session titles, progress narration | `anthropic/claude-haiku-5-5` | none: OpenClaw's default small model for Anthropic |

These replace Sonnet 4.6 for the default and Haiku 4.5 for the rest. Prices per million tokens, input and output:

| Model | Input | Output |
|---|---|---|
| Opus 5.5 | $4 | $20 |
| Haiku 5.5, prompt of 100,000 tokens or fewer | $0.10 | $0.50 |
| Haiku 5.5, longer prompt | $0.50 | $2.50 |
| Sonnet 4.6 (was the default) | $3 | $15 |
| Haiku 4.5 (was heartbeat and compaction) | $1 | $5 |

Both 5.5 models think on every request; OpenClaw runs them at medium effort. Each model has an entry under `agents.defaults.models` asking for an hour of prompt cache (`cacheRetention: long`); a model with no entry gets five minutes.

`agents.defaults.modelPolicy.allow` lists the same two models, and decides what `/model` may switch a chat session to. It does not restrict the configured models above, or an automation that names its own model. Before OpenClaw 2026.8.1 the keys of `agents.defaults.models` did this job; on a volume from an older release, `openclaw doctor --fix` copies those keys into `modelPolicy.allow` once, which would have kept the retired `claude-opus-4-6` and `claude-haiku-4-5` there for good. The entrypoint writes the list itself instead.

To change a model, edit `chatModel` or `utilityModel` in `entrypoint.sh`. A model set inside the container with `openclaw config set` lasts until the next start. To check that a model id is in the pinned release's catalog:

```bash
docker exec poiesis openclaw models list --provider anthropic --all
```

An automation registered with its own `--model` keeps that model when the defaults change:

```bash
docker exec poiesis openclaw automations list
docker exec poiesis openclaw automations edit <id> --clear-model
```

## OpenClaw Configuration

### Doctor Runs on Every Start

`openclaw doctor --fix --non-interactive` runs on every start, after onboarding and before the entrypoint writes its configuration. The pinned gateway does not repair state an older release left behind: it exits with code 78. On a volume written by 2026.7.1 it says `OpenClaw state database schema migration required (audit-events-v2)`. OpenClaw's own container image runs doctor before every gateway start for this reason, and its documentation says a custom entrypoint has to do the same.

Doctor migrates legacy state into SQLite (keeping a copy first), moves retired configuration keys, and enables or disables bundled skills to match the tools installed. On a volume with nothing to migrate, that last step is all it does. When it exits non-zero, the container starts the gateway anyway and prints doctor's last lines, with secrets redacted:

```
doctor: openclaw doctor --fix exited 1. The gateway checks the state it
  left and refuses to start if a store it needs is unsafe. openclaw doctor said:
```

If the gateway then exits with code 78, its own message names the store. To see doctor's full report against the same volume:

```bash
docker run --rm -v /opt/poiesis/data:/root/.openclaw --entrypoint openclaw \
  svanosselaer/poiesis-service:latest doctor --fix
```

### The Tool Profile Is Left Unset

`tools.profile` chooses which tools the agent may call before `tools.deny` narrows it. The entrypoint deletes it on every start. Unset means no filtering of OpenClaw's core tools, which is what `full` meant in 2026.7.1 ("No restriction (same as unset)"). In 2026.9.37, `full` also turns on the optional tools of every enabled plugin — Firecrawl's `firecrawl_search` and `firecrawl_scrape`, when `FIRECRAWL_API_KEY` is set — and onboarding writes `full` on a new volume. The entrypoint used to write `full` itself; removing the key keeps the agent's tools what they were. `tools.deny: ["gateway"]` still applies.

### Environment Variables in the Configuration

`ANTHROPIC_API_KEY` and `GITHUB_TOKEN` are written under `env.vars`. 2026.7.1 accepted variables placed directly under `env`, which is where the entrypoint used to put them; 2026.9.37 rejects the configuration with `env: Unrecognized keys`. The entrypoint now removes them from there.
