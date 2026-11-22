#!/usr/bin/env bash
set -euo pipefail

redact_secrets() {
  local text="$1" secret
  for secret in "${ANTHROPIC_API_KEY:-}" "${GITHUB_TOKEN:-}" \
                "${CLAUDE_CODE_OAUTH_TOKEN:-}" "${BRAVE_API_KEY:-}" \
                "${FIRECRAWL_API_KEY:-}" "${TELEGRAM_BOT_TOKEN:-}" \
                "${SLACK_BOT_TOKEN:-}" "${SLACK_APP_TOKEN:-}"; do
    if [ -n "$secret" ]; then
      text="${text//"$secret"/[redacted]}"
    fi
  done
  printf '%s\n' "$text"
}

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

doctor_status=0
doctor_output="$(openclaw doctor --fix --non-interactive 2>&1)" || doctor_status=$?
if [ "$doctor_status" -ne 0 ]; then
  {
    echo "doctor: openclaw doctor --fix exited ${doctor_status}. The gateway checks the state it"
    echo '  left and refuses to start if a store it needs is unsafe. openclaw doctor said:'
    redact_secrets "$doctor_output" | tail -n 5 | sed 's/^/    /'
  } >&2
fi

node -e "
  const chatModel = 'anthropic/claude-opus-5-5';
  const utilityModel = 'anthropic/claude-haiku-5-5';

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
  config.agents.defaults.model = chatModel;
  config.agents.defaults.heartbeat = {
    every: '59m',
    target: 'last',
    model: utilityModel,
    lightContext: true
  };
  config.agents.defaults.compaction = { model: utilityModel };
  config.agents.defaults.models = {
    [chatModel]: {
      params: { cacheRetention: 'long' }
    },
    [utilityModel]: {
      params: { cacheRetention: 'long' }
    }
  };
  config.agents.defaults.modelPolicy = { allow: [chatModel, utilityModel] };
  config.tools = config.tools || {};
  delete config.tools.profile;
  delete config.tools.allow;
  config.tools.deny = ['gateway'];
  config.cron = { enabled: true };
  config.env = config.env || {};
  delete config.env.ANTHROPIC_API_KEY;
  delete config.env.GITHUB_TOKEN;
  config.env.vars = config.env.vars || {};
  config.env.vars.ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
  if (process.env.GITHUB_TOKEN) {
    config.env.vars.GITHUB_TOKEN = process.env.GITHUB_TOKEN;
  }
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

POIESIS_HOST_PORT_PREFIX="${POIESIS_HOST_PORT_PREFIX:-3}"
if ! [[ "$POIESIS_HOST_PORT_PREFIX" =~ ^[1-9]$ ]]; then
  echo "Warning: POIESIS_HOST_PORT_PREFIX='${POIESIS_HOST_PORT_PREFIX}' is not a single digit 1-9; falling back to default '3'" >&2
  POIESIS_HOST_PORT_PREFIX=3
fi
export POIESIS_HOST_PORT_PREFIX

image_namespace_source="POIESIS_IMAGE_NAMESPACE"
if [ -z "${POIESIS_IMAGE_NAMESPACE:-}" ]; then
  POIESIS_IMAGE_NAMESPACE="$(printf '%s' "$POIESIS_GITHUB_OWNER" | tr '[:upper:]' '[:lower:]')"
  image_namespace_source="POIESIS_IMAGE_NAMESPACE (unset, so taken from POIESIS_GITHUB_OWNER)"
fi
if ! [[ "$POIESIS_IMAGE_NAMESPACE" =~ ^[a-z0-9]+([._-][a-z0-9]+)*$ ]]; then
  echo "Error: ${image_namespace_source} is '${POIESIS_IMAGE_NAMESPACE}', which is not a valid registry namespace." >&2
  echo "  Use lowercase letters and digits, separated by single '.', '_' or '-' (for example svanosselaer)." >&2
  exit 1
fi
export POIESIS_IMAGE_NAMESPACE

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN is required for GitHub access" >&2
  exit 1
fi

echo "$GITHUB_TOKEN" | env -u GITHUB_TOKEN -u GH_TOKEN gh auth login --with-token
echo "$GITHUB_TOKEN" | env -u GITHUB_TOKEN -u GH_TOKEN runuser -u claude -- gh auth login --with-token
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
POIESIS_HOST_PORT_PREFIX="${POIESIS_HOST_PORT_PREFIX}" \\
POIESIS_IMAGE_NAMESPACE="${POIESIS_IMAGE_NAMESPACE}" \\
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

## Scaffolding configuration

Claude Code scaffolds with these two settings. The cycle command above passes them to
it in its environment. Claude Code runs as \`claude\` and cannot read this file, so keep
both assignments in the command whenever you run it; without them it falls back to
prefix \`3\` and the GitHub owner as the namespace.

\`POIESIS_HOST_PORT_PREFIX\`: \`${POIESIS_HOST_PORT_PREFIX}\` (single digit 1-9; default 3).
The prefix for every host-mapped port in the generated Vagrantfile and in any document
that references those ports (parent CLAUDE.md, README.md, .specs/initial/SPEC.md). With
prefix \`${POIESIS_HOST_PORT_PREFIX}\`, guest port \`8001\` maps to host port \`${POIESIS_HOST_PORT_PREFIX}8001\` and guest port \`3000\` to
host port \`${POIESIS_HOST_PORT_PREFIX}3000\`.

\`POIESIS_IMAGE_NAMESPACE\`: \`${POIESIS_IMAGE_NAMESPACE}\` (default: the GitHub owner).
The registry namespace for every generated image name, \`<namespace>/<project>-<service>-service\`,
in each service's \`docker-tag\` and in the Vagrantfile. Repositories still go under the
GitHub owner.

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
    config.plugins = config.plugins || {};
    config.plugins.entries = config.plugins.entries || {};
    config.plugins.entries.slack = Object.assign({}, config.plugins.entries.slack, { enabled: true });
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
  "
fi

exec openclaw gateway --port 3000 --bind lan
