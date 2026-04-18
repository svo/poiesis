---
name: scaffold-services
description: Creates new service repositories from templates and adds them as git submodules. Handles repo creation from svo/python-sprint-zero or svo/www-qual-is templates, template purge, reference renaming, port assignment using POIESIS_HOST_PORT_PREFIX, Docker-provider Vagrantfile updates, docker-tag normalisation, and CLAUDE.md configuration. Frontend invocations also wire same-origin API proxy routes.
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(git *), Bash(cd *), Bash(find *), Bash(fgrep *), Bash(sed *), Bash(mv *), Read, Edit, Write, Grep, Glob
---

# Scaffold Services

Creates new service repositories from templates and wires them into the project as submodules.

## Usage

`/scaffold-services <service-name> <template> <port> <description>`

Arguments:
- `$0`: Service name in kebab-case (e.g. `event-processor`)
- `$1`: Template — either `python` (uses `svo/python-sprint-zero`) or `frontend` (uses `svo/www-qual-is`)
- `$2`: Guest port (host port becomes `${PORT_PREFIX}$2` where `${PORT_PREFIX}` is read from the workspace `AGENTS.md`)
- `$3`: One-line description of the service

The host-port prefix is the value of `POIESIS_HOST_PORT_PREFIX` documented in the workspace `AGENTS.md` (single digit `1`–`9`, default `3`). Read it once at the start of the run and reuse it.

## Steps

1. **Read the project's CLAUDE.md** to determine the GitHub owner and project name. Read `~/.openclaw/workspace/AGENTS.md` to determine `${PORT_PREFIX}`.

2. **Create the GitHub repo from template:**

```bash
gh repo create ${GITHUB_OWNER}/${PROJECT_NAME}-$0 --template svo/$1-sprint-zero --private
gh api repos/${GITHUB_OWNER}/${PROJECT_NAME}-$0/actions/permissions --method PUT -F enabled=false
```

For frontend template use `svo/www-qual-is` instead.

**Do not remove `.github/workflows` from the service repository.** The workflows are disabled at the repo level and will be re-enabled later.

3. **Add as submodule** using the `https://github.com/...` form (the entrypoint rewrites SSH to HTTPS so tokens never reach `.gitmodules`):

For backend services:
```bash
git submodule add https://github.com/${GITHUB_OWNER}/${PROJECT_NAME}-$0.git services/$0
```

For frontend:
```bash
git submodule add https://github.com/${GITHUB_OWNER}/${PROJECT_NAME}-$0.git ui
```

4. **Purge template scaffolding** by invoking the `/purge-template` skill immediately after the submodule is added, before any renaming:

```bash
# Backend
/purge-template python-sprint-zero services/$0

# Frontend
/purge-template www-qual-is ui
```

5. **Rename template references** (Python services only):

Derive the underscore and titlecase forms of the service name, then:

```bash
underscore=$(echo $0 | tr '-' '_')
titlecase=$(echo $0 | sed 's/-/ /g' | sed 's/\b\w/\u&/g')

# File contents
fgrep -rl python-sprint-zero . | xargs sed -i "s/python-sprint-zero/${PROJECT_NAME}-$0/g"
fgrep -rl python_sprint_zero . | xargs sed -i "s/python_sprint_zero/${PROJECT_NAME//-/_}_${underscore}/g"
fgrep -rl "Python Sprint Zero" . | xargs sed -i "s/Python Sprint Zero/${PROJECT_TITLE} ${titlecase}/g"

# File and directory names (depth-first)
find . -depth -name "*python_sprint_zero*" | while read f; do
  mv "$f" "$(echo $f | sed "s/python_sprint_zero/${PROJECT_NAME//-/_}_${underscore}/g")"
done
find . -depth -name "*python-sprint-zero*" | while read f; do
  mv "$f" "$(echo $f | sed "s/python-sprint-zero/${PROJECT_NAME}-$0/g")"
done
```

6. **Update the parent Vagrantfile** — append a new `config.vm.define` block using the Docker provider. Do not use `config.vm.network "forwarded_port"` — every service is its own container.

For a backend:

```ruby
config.vm.define "$0" do |s|
  s.vm.provider :docker do |d|
    d.image = "${GITHUB_OWNER}/${PROJECT_NAME}-$0-service:latest"
    d.name  = "${PROJECT_NAME}-$0"
    d.ports = ["${PORT_PREFIX}$2:$2"]
    d.env   = {
      # One entry per other backend this service calls.
      "APP_<OTHER_BACKEND>_URL" => "http://host.docker.internal:${PORT_PREFIX}<OTHER_GUEST_PORT>"
    }
  end
end
```

For a frontend:

```ruby
config.vm.define "$0" do |s|
  s.vm.provider :docker do |d|
    d.image = "${GITHUB_OWNER}/${PROJECT_NAME}-$0-service:latest"
    d.name  = "${PROJECT_NAME}-$0"
    d.ports = ["${PORT_PREFIX}$2:$2"]
    d.env   = {
      # One entry per backend the frontend proxies to. Server-only — never NEXT_PUBLIC_.
      "<BACKEND>_URL" => "http://host.docker.internal:${PORT_PREFIX}<BACKEND_GUEST_PORT>"
    }
  end
end
```

When this skill is invoked with `--template frontend`, also wire the API proxy route handlers — see "Frontend wiring" below.

7. **Update the service's `.claude/CLAUDE.md`** — add a `## Project Purpose` section with `### Core Domain Concepts` subsection after the top-level title. Include the guest port and the host port (`${PORT_PREFIX}$2`).

8. **Normalise the docker-tag** in `infrastructure/packer/service.pkr.hcl`. Edit the `docker-tag` value to exactly:

```
${GITHUB_OWNER}/${PROJECT_NAME}-$0-service
```

This applies to **both** backend and frontend services. For the frontend, verify the resulting tag does not contain the substring `www-qual-is`:

```bash
if fgrep -q 'www-qual-is' infrastructure/packer/service.pkr.hcl; then
  echo 'docker-tag still references www-qual-is' >&2
  exit 1
fi
```

9. **Commit and push** the submodule changes, then update the parent repo's submodule reference.

10. **Update the parent docs** (`CLAUDE.md`, `README.md`, and `.specs/initial/SPEC.md` if present) so every host-port and image-name reference matches what was actually generated. The Vagrantfile is the source of truth — the docs must agree with it.

## Frontend wiring (`$1 == frontend`)

When the template is `frontend`, also generate one Next.js App Router catch-all route handler per backend service the frontend talks to. This keeps the browser on same-origin URLs and avoids `NEXT_PUBLIC_*` / runtime-config injection.

For each backend `<service>` create `ui/src/app/api/<service>/[...path]/route.ts` exporting `GET`, `POST`, `PUT`, `PATCH`, `DELETE` that:

- Read `process.env.<SERVICE>_URL` (server-only — populated by the frontend's `docker.env` in Step 6).
- Build `proxyURL = new URL(path.join('/') + request.nextUrl.search, UPSTREAM)`.
- Forward via `fetch(new Request(proxyURL, request))` inside `try/catch`.
- On `fetch` failure return HTTP 502 with a structured JSON error body (`{ error, service, detail }`).
- If `<SERVICE>_URL` is unset, return HTTP 502 with `error: "upstream_not_configured"`.

Then update the frontend's repository classes (`Http<Service>Repository` and similar) to call `/api/<service>/...` (same origin) and remove every `NEXT_PUBLIC_*_URL` reference plus any `window.__RUNTIME_CONFIG__` injection. The detailed code template lives in the `monitor-and-scaffold` and `scaffold-project` prompts — emit the same shape here so ad-hoc `/scaffold-services <name> frontend ...` runs match the cron flow.

## Port Convention

Backend guest ports start at `8001` and increment per service. The frontend uses guest port `3000`. Host ports are `${PORT_PREFIX}<guest>` where `${PORT_PREFIX}` is the single-digit value of `POIESIS_HOST_PORT_PREFIX` (default `3`). For example, with the default prefix, guest `8001` maps to host `38001` and guest `3000` maps to host `33000`.
