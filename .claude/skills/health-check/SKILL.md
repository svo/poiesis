---
name: health-check
description: Checks the health of the running Poiesis service container. Reports container status, port 3000 reachability, workspace-file state under /root/.openclaw, and recent entrypoint activity. Use when debugging a failing deploy or verifying the service is up.
disable-model-invocation: true
allowed-tools: Bash(docker ps*), Bash(docker logs*), Bash(docker exec*), Bash(docker inspect*), Bash(curl *)
---

# Health Check

Verify the Poiesis service container is running and operational.

## Usage

`/health-check` (defaults to container name `poiesis`; accept an override as the first argument).

## Process

1. **Container status:**

```bash
docker ps -a --filter "name=^poiesis$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

   Flag if the container doesn't exist, isn't running, or has recently restarted.

2. **Port reachability** on the host-mapped `127.0.0.1:3000`:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000/
```

3. **Workspace files present:**

```bash
docker exec poiesis ls /root/.openclaw/workspace
```

   Expect `IDENTITY.md`, `SOUL.md`, `AGENTS.md`, `USER.md`. Missing files mean entrypoint bootstrap didn't run or failed.

4. **Startup log** — look for OpenClaw onboarding completion and env-var validation:

```bash
docker logs --tail 200 poiesis
```

   Startup failures usually show a missing `POIESIS_*` or `GITHUB_TOKEN` variable near the top of the log.

5. **Recent agent activity** — session logs under the persisted volume:

```bash
docker exec poiesis ls -lt /root/.openclaw 2>/dev/null | head
```

   If the last activity is older than expected given `POIESIS_CRON_SCHEDULE` and `POIESIS_TIMEZONE`, flag it.

6. **Report** as a table: container running, port reachable, workspace files present, auth configured (`ANTHROPIC_API_KEY` / `GITHUB_TOKEN`; optional `CLAUDE_CODE_OAUTH_TOKEN`), recent activity. For any failure, suggest the likely cause and a next step — often `/run-service` after correcting env vars.
