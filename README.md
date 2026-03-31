<p align="center">
  <img src="icon.png" alt="Poiesis" width="128">
</p>

# Poiesis

[![Build Development](https://github.com/svo/poiesis/actions/workflows/development.yml/badge.svg)](https://github.com/svo/poiesis/actions/workflows/development.yml)
[![Build Builder](https://github.com/svo/poiesis/actions/workflows/builder.yml/badge.svg)](https://github.com/svo/poiesis/actions/workflows/builder.yml)
[![Build Service](https://github.com/svo/poiesis/actions/workflows/service.yml/badge.svg)](https://github.com/svo/poiesis/actions/workflows/service.yml)

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
  -e POIESIS_CRON_SCHEDULE="0 8 * * 1" \
  -e POIESIS_TIMEZONE="Australia/Melbourne" \
  -v /opt/poiesis/data:/root/.openclaw \
  -p 127.0.0.1:3000:3000 \
  svanosselaer/poiesis-service:latest
```

On first run, the entrypoint automatically configures OpenClaw via non-interactive onboarding and sets up web search, web fetch, and messaging access. Configuration is persisted to the volume at `/root/.openclaw` so subsequent starts skip onboarding.

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key for the OpenClaw gateway |
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

## Switching from API Key to Claude Subscription

If you have a Claude Pro or Max subscription, you can use it instead of an API key.

1. On a machine with Claude Code installed, generate a setup token:
   ```bash
   claude setup-token
   ```
2. Copy the token and paste it into the running container:
   ```bash
   docker exec -it poiesis openclaw models auth paste-token --provider anthropic
   ```

3. Set the subscription as the default auth method:
   ```bash
   docker exec -it poiesis openclaw models auth order set --provider anthropic anthropic:manual anthropic:default
   ```

## Workspace Instructions

On startup, the entrypoint generates OpenClaw workspace files at `~/.openclaw/workspace/` using the `POIESIS_*` environment variables and sets `agent.skipBootstrap: true` so OpenClaw uses the pre-seeded files directly:

| File | Content |
|---|---|
| `IDENTITY.md` | Name, vibe, and emoji |
| `SOUL.md` | Persona, tone, and boundaries for a project-scaffolding agent |
| `AGENTS.md` | Operating instructions — blog monitoring, concept extraction, scaffolding process, and schedule |
| `USER.md` | GitHub owner and timezone |

These files are injected into the agent's context at the start of every session, so Poiesis knows how to identify software concepts and scaffold projects immediately.

All `POIESIS_*` variables are required — the container will fail on startup if any are missing. `GITHUB_TOKEN` is also required and validated separately.
