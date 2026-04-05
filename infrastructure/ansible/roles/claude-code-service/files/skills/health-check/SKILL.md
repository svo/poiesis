---
name: health-check
description: Checks the health and status of all project services. Reports which services are running, reachable, and responding on their expected ports. Use when debugging connectivity issues or verifying services are up.
disable-model-invocation: true
allowed-tools: Bash(curl *), Bash(lsof *), Bash(ps *), Bash(docker *), Bash(grep *)
---

# Health Check

Verify that all project services are running and reachable.

## Usage

`/health-check`

## Process

1. **Read the project's CLAUDE.md or Vagrantfile** to determine the expected services and their ports.

2. **Check Docker container status:**

```bash
docker ps --filter "name=${PROJECT_NAME}-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

3. **Check each port is reachable:**

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/health || echo "DOWN"
```

4. **Report** the status of each service in a table:

| Service | Port | Status |
|---------|------|--------|
| ...     | ...  | ...    |

5. For any services that are down, check if the Docker container exists but is stopped, and suggest `/run-service` to start them.

6. To verify the correct image is running, resolve the expected `docker-tag` from each service's `infrastructure/packer/service.pkr.hcl` and compare against the running container's image.
