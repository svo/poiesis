---
name: run-service
description: Starts the Poiesis service container locally from the published svanosselaer/poiesis-service image with the required environment variables. Use when the user wants to run, restart, or stop Poiesis on their machine.
disable-model-invocation: true
allowed-tools: Bash(docker *), Bash(test *)
---

# Run Service

Start the Poiesis service container locally.

## Usage

- `/run-service` — start a fresh container named `poiesis`
- `/run-service stop` — stop and remove the container

## Required Environment

The container fails fast if any required variable is missing. Before starting, confirm these are set in the invoking shell (or ask the user to provide them):

- `ANTHROPIC_API_KEY` — required
- `GITHUB_TOKEN` — required, `repo` scope
- `POIESIS_BLOG_URL`, `POIESIS_GITHUB_OWNER`, `POIESIS_CRON_SCHEDULE`, `POIESIS_TIMEZONE` — all required

Optional:

- `CLAUDE_CODE_OAUTH_TOKEN` — use a Claude subscription for Claude Code
- `BRAVE_API_KEY`, `FIRECRAWL_API_KEY` — web search / scraping
- `TELEGRAM_BOT_TOKEN` + `TELEGRAM_ALLOW_FROM`
- `SLACK_BOT_TOKEN` + `SLACK_APP_TOKEN`

## Start

```bash
docker run -d \
  --name poiesis \
  --restart unless-stopped \
  --pull always \
  -e ANTHROPIC_API_KEY \
  -e GITHUB_TOKEN \
  -e POIESIS_BLOG_URL \
  -e POIESIS_GITHUB_OWNER \
  -e POIESIS_CRON_SCHEDULE \
  -e POIESIS_TIMEZONE \
  ${CLAUDE_CODE_OAUTH_TOKEN:+-e CLAUDE_CODE_OAUTH_TOKEN} \
  ${BRAVE_API_KEY:+-e BRAVE_API_KEY} \
  ${FIRECRAWL_API_KEY:+-e FIRECRAWL_API_KEY} \
  ${TELEGRAM_BOT_TOKEN:+-e TELEGRAM_BOT_TOKEN} \
  ${TELEGRAM_ALLOW_FROM:+-e TELEGRAM_ALLOW_FROM} \
  ${SLACK_BOT_TOKEN:+-e SLACK_BOT_TOKEN} \
  ${SLACK_APP_TOKEN:+-e SLACK_APP_TOKEN} \
  -v /opt/poiesis/data:/root/.openclaw \
  -p 127.0.0.1:3000:3000 \
  svanosselaer/poiesis-service:latest
```

After start, confirm the entrypoint completes OpenClaw onboarding (first run only) or reports `agent.skipBootstrap` on subsequent runs:

```bash
docker logs -f poiesis
```

## Stop

```bash
docker stop poiesis && docker rm poiesis
```

## Running a locally built image

To run a locally built image instead of the published `:latest`, substitute the local tag (e.g. `svanosselaer/poiesis-service:arm64` after `./build.sh service arm64`) and drop `--pull always`.

## Related

- First-time volume setup and onboarding: see `README.md`
- After start, use `/health-check` to verify reachability and workspace files
