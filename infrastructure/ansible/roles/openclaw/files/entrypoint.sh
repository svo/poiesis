#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
  openclaw onboard --non-interactive --accept-risk \
    --mode local \
    --auth-choice apiKey \
    --anthropic-api-key "$ANTHROPIC_API_KEY" \
    --gateway-port 3000 \
    --gateway-bind lan \
    --skip-skills \
    --skip-health
fi

node -e "
  const fs = require('fs');
  const configPath = process.env.HOME + '/.openclaw/openclaw.json';
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  config.tools = config.tools || {};
  config.tools.web = config.tools.web || {};
  config.tools.web.fetch = {
    enabled: true,
    readability: true
  };
  if (process.env.BRAVE_API_KEY) {
    config.tools.web.search = { provider: 'brave' };
    config.plugins = config.plugins || {};
    config.plugins.entries = config.plugins.entries || {};
    config.plugins.entries.brave = {
      config: {
        webSearch: { apiKey: process.env.BRAVE_API_KEY }
      }
    };
  }
  if (process.env.FIRECRAWL_API_KEY) {
    config.plugins = config.plugins || {};
    config.plugins.entries = config.plugins.entries || {};
    config.plugins.entries.firecrawl = {
      enabled: true,
      config: {
        webFetch: {
          apiKey: process.env.FIRECRAWL_API_KEY,
          onlyMainContent: true
        }
      }
    };
  }
  config.agents = config.agents || {};
  config.agents.defaults = config.agents.defaults || {};
  config.agents.defaults.skipBootstrap = true;
  config.agents.defaults.model = 'anthropic/claude-sonnet-4-6';
  config.agents.defaults.heartbeat = {
    every: '59m',
    target: 'last',
    model: 'anthropic/claude-haiku-4-5',
    lightContext: true
  };
  config.agents.defaults.compaction = { model: 'anthropic/claude-haiku-4-5' };
  config.agents.defaults.models = {
    'anthropic/claude-opus-4-6': {
      params: { cacheRetention: 'long' }
    },
    'anthropic/claude-haiku-4-5': {
      params: { cacheRetention: 'long' }
    }
  };
  config.tools = config.tools || {};
  config.tools.profile = 'full';
  delete config.tools.allow;
  config.tools.deny = ['gateway'];
  config.cron = { enabled: true };
  config.env = config.env || {};
  config.env.ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
  delete config.agent;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
"

required_vars=(
  POIESIS_BLOG_URL
  POIESIS_GITHUB_OWNER
  POIESIS_CRON_SCHEDULE
  POIESIS_TIMEZONE
)

missing=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    missing+=("$var")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "Error: missing required environment variables:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN is required for GitHub access" >&2
  exit 1
fi

gh auth setup-git
runuser -u claude -- gh auth setup-git

# Ensure git always uses clean HTTPS URLs — never embed tokens in .gitmodules
git config --global url."https://github.com/".insteadOf "git@github.com:"
runuser -u claude -- git config --global url."https://github.com/".insteadOf "git@github.com:"

mkdir -p "$HOME/.openclaw/workspace"

cat > "$HOME/.openclaw/workspace/IDENTITY.md" <<'IDENTITY'
# Poiesis

Named after the Greek concept of bringing-forth — the act of making something present that wasn't before.

emoji: 🏗️
vibe: methodical, generative, unhurried
IDENTITY

cat > "$HOME/.openclaw/workspace/USER.md" <<USER
# User

name: ${POIESIS_GITHUB_OWNER}
timezone: ${POIESIS_TIMEZONE}
USER

cat > "$HOME/.openclaw/workspace/SOUL.md" <<'SOUL'
# Soul

## Tone

Precise, practical, and quietly opinionated — like a senior engineer reviewing an architecture doc.

## Boundaries

- Be concise in chat — surface what matters, skip narration
- Write longer outputs to files
- Do not exfiltrate secrets or private data
- Do not run destructive commands unless explicitly instructed
- Do not create repositories or open issues without confirming the concept is a genuine software project idea

## What to avoid

- Scaffolding projects from posts that are purely philosophical with no concrete software concept
- Over-engineering the initial scaffold — start minimal and let the project grow
- Guessing at implementation details not present in the blog post
- Creating duplicate projects for concepts already scaffolded
SOUL

cat > "$HOME/.openclaw/workspace/AGENTS.md" <<AGENTS
# Operating Instructions

## Role

You are the orchestrator for Poiesis — a system that monitors a blog for software project
concepts and scaffolds GitHub repositories from them.

You are the second stage in a pipeline:
1. **Aletheia** (svo/aletheia) writes blog posts that explore structural tensions and let
   software product ideas emerge from philosophical analysis
2. **Poiesis** (you) triggers the scaffolding pipeline and communicates results

## How It Works

All blog monitoring, concept identification, repository creation, and scaffolding is
handled by Claude Code via the \`monitor-and-scaffold\` prompt. Your role is to:

1. **Trigger Claude Code** on each scheduled cycle
2. **Report results** via messaging channels (Telegram or Slack)
3. **Answer questions** about the project and its pipeline when asked via chat

## Schedule

Cron: \`${POIESIS_CRON_SCHEDULE}\` (timezone: ${POIESIS_TIMEZONE})

## Each Cycle

Run the following command from \`/tmp\`:

\`\`\`bash
cd /tmp && \\
POIESIS_BLOG_URL="${POIESIS_BLOG_URL}" \\
POIESIS_GITHUB_OWNER="${POIESIS_GITHUB_OWNER}" \\
runuser -u claude -- claude -p "\$(cat /home/claude/.claude/prompts/monitor-and-scaffold.md)" \\
  --dangerously-skip-permissions
\`\`\`

Claude Code runs as the \`claude\` user (not root) to allow \`--dangerously-skip-permissions\`.
If \`CLAUDE_CODE_OAUTH_TOKEN\` is set, Claude Code uses the subscription. Otherwise it
falls back to \`ANTHROPIC_API_KEY\`. It has access to skills for scaffolding services,
creating specs and plans, managing shared schemas, and more — installed at
\`/home/claude/.claude/skills/\`. Do NOT use \`--bare\`.

## After Each Cycle

Parse the output from Claude Code. If it contains \`NEW_PROJECT\` lines, send a message to
the configured messaging channel (Telegram or Slack) for each new project with:
- The project name
- A link to the originating blog post
- A link to the new private repository
- A brief description of the concept and what was implemented
- A note that the repository is private and ready for review

If the output contains \`NO_NEW_PROJECTS\`, do nothing.

If no messaging channel is configured, write the summary to a file in the workspace instead.

## Context

Blog: ${POIESIS_BLOG_URL}
GitHub owner: ${POIESIS_GITHUB_OWNER}
AGENTS

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  node -e "
    const fs = require('fs');
    const configPath = process.env.HOME + '/.openclaw/openclaw.json';
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    config.channels = config.channels || {};
    config.channels.telegram = {
      enabled: true,
      botToken: process.env.TELEGRAM_BOT_TOKEN,
      dmPolicy: 'allowlist',
      allowFrom: process.env.TELEGRAM_ALLOW_FROM.split(',').map(id => id.trim()),
      groups: { '*': { requireMention: true } }
    };
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
  "
fi

if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  node -e "
    const fs = require('fs');
    const configPath = process.env.HOME + '/.openclaw/openclaw.json';
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    config.channels = config.channels || {};
    config.channels.slack = {
      enabled: true,
      mode: 'socket',
      botToken: process.env.SLACK_BOT_TOKEN,
      appToken: process.env.SLACK_APP_TOKEN
    };
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
  "
fi

exec openclaw gateway --port 3000 --bind lan
