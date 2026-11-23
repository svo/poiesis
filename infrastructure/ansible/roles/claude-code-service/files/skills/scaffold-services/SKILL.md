---
name: scaffold-services
description: Creates new service repositories from templates and adds them as git submodules. Handles repo creation from svo/python-sprint-zero or svo/www-qual-is templates, template purge, reference renaming, port assignment using POIESIS_HOST_PORT_PREFIX, image naming using POIESIS_IMAGE_NAMESPACE, Docker-provider Vagrantfile updates, docker-tag normalisation, and CLAUDE.md configuration. Frontend invocations also wire same-origin API proxy routes.
allowed-tools: Bash(gh *), Bash(git *), Bash(cd *), Bash(find *), Bash(fgrep *), Bash(sed *), Bash(mv *), Bash(xargs *), Bash(printf *), Bash(poiesis-purge-check *), Read, Edit, Write, Grep, Glob
---

# Scaffold Services

Creates new service repositories from templates and wires them into the project as submodules.

## Usage

`/scaffold-services <service-name> <template> <port> <description>`

Arguments:
- `$0`: Service name in kebab-case (e.g. `event-processor`)
- `$1`: Template — either `python` (uses `svo/python-sprint-zero`) or `frontend` (uses `svo/www-qual-is`)
- `$2`: Guest port (host port becomes `${PORT_PREFIX}$2`; see Settings)
- `$3`: One-line description of the service

## Settings

Read both from the environment once, at the start of the run, and reuse them:

```bash
PORT_PREFIX="${POIESIS_HOST_PORT_PREFIX:-3}"
IMAGE_NAMESPACE="${POIESIS_IMAGE_NAMESPACE:-$GITHUB_OWNER}"
```

- `${PORT_PREFIX}` is a single digit `1`–`9` (default `3`) placed in front of every guest port to make its host port.
- `${IMAGE_NAMESPACE}` is the registry namespace for every image name (default: the GitHub owner). GitHub repositories live under `${GITHUB_OWNER}`; images live under `${IMAGE_NAMESPACE}`. The two can differ.

## Steps

1. **Read the project's CLAUDE.md** to determine the GitHub owner and project name. Read `${PORT_PREFIX}` and `${IMAGE_NAMESPACE}` from the environment (see Settings).

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

4. **Purge template scaffolding** by invoking the `purge-template` skill immediately after the submodule is added, before any renaming:

```
/purge-template python-sprint-zero services/$0   # backend
/purge-template www-qual-is ui                   # frontend
```

5. **Rename template references and set the port.** Work inside the submodule (`cd services/$0` or `cd ui`).

For a backend (`python`), rename the template references in three forms:

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

Then write the guest port into `application.properties` as a line of its own. The purge left the file ending in a newline, so append; never edit the `host` line:

```bash
props=$(find src -path '*/resources/application.properties')
sed -i '/^port=/d' "$props"
printf 'port=%s\n' "$2" >> "$props"
```

For a frontend (`frontend`), replace the template name with `${PROJECT_NAME}-$0` in file contents and in file and directory names:

```bash
fgrep -rl www-qual-is . | xargs sed -i "s/www-qual-is/${PROJECT_NAME}-$0/g"
find . -depth -name "*www-qual-is*" | while read f; do
  mv "$f" "$(echo $f | sed "s/www-qual-is/${PROJECT_NAME}-$0/g")"
done
```

Then rewrite each remaining `qual.is` reference in context. Never delete the text with `sed`:

- **Site URL** — `https://www.qual.is` in `metadataBase`, canonical and Open Graph URLs, JSON-LD and `src/lib/constants.ts`: read a `SITE_URL` setting that defaults to `http://localhost:${PORT_PREFIX}$2`.
- **Brand text** — `qual.is` in the navigation, footer, page titles, `not-found`, the web manifest, `README.md` and `run.sh`: the project title.
- **Analytics** — remove the analytics script from `src/app/layout.tsx` and its entries in the content-security-policy in `next.config.js`.
- **`public/robots.txt`** — disallow everything (`User-agent: *`, `Disallow: /`) and drop the `Sitemap:` line.
- **Contact address** — remove the `mailto:` link to a `qual.is` address.
- **Template reference notes** under `.claude/skills/*/references/` that quote the blog's code: delete them.
- Update the tests that assert on any of the above.

If a reference must stay on purpose (for example a licence attribution), list its path, relative to the submodule root, in `.purge-allow`, one per line. The check prints every path that file allows.

6. **Check before pushing.** From the parent repo, after the rename and port are done:

```bash
poiesis-purge-check python-sprint-zero services/$0   # backend
poiesis-purge-check www-qual-is ui                   # frontend
```

It names each file that still carries template residue and exits non-zero. Fix what it names and run it again. Do not push the submodule, or the parent's reference to it, until it exits 0.

7. **Update the parent Vagrantfile** — append a new `config.vm.define` block using the Docker provider. Do not use `config.vm.network "forwarded_port"` — every service is its own container.

For a backend:

```ruby
config.vm.define "$0" do |s|
  s.vm.provider :docker do |d|
    d.image = "${IMAGE_NAMESPACE}/${PROJECT_NAME}-$0-service:latest"
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
    d.image = "${IMAGE_NAMESPACE}/${PROJECT_NAME}-$0-service:latest"
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

8. **Update the service's `.claude/CLAUDE.md`** — add a `## Project Purpose` section with `### Core Domain Concepts` subsection after the top-level title. Include the guest port and the host port (`${PORT_PREFIX}$2`).

9. **Normalise the image names** in the service. Edit the `docker-tag` value in `infrastructure/packer/service.pkr.hcl` to exactly:

```
${IMAGE_NAMESPACE}/${PROJECT_NAME}-$0-service
```

This applies to **both** backend and frontend services. The template's other image names (the builder, development, mock and documentation repositories in `infrastructure/packer/*.pkr.hcl`, the root `*.sh` scripts and the service's own `Vagrantfile`) use the template's namespace, `svanosselaer/`. Replace it with the configured one; nothing changes when the two are equal:

```bash
fgrep -rl 'svanosselaer/' infrastructure/packer ./*.sh Vagrantfile | xargs sed -i "s|svanosselaer/|${IMAGE_NAMESPACE}/|g"
```

10. **Commit and push** the submodule changes, then update the parent repo's submodule reference. Step 6 must have exited 0 first.

11. **Update the parent docs** (`CLAUDE.md`, `README.md`, and `.specs/initial/SPEC.md` if present) so every host-port and image-name reference matches what was actually generated. The Vagrantfile is the source of truth — the docs must agree with it.

## Frontend wiring (`$1 == frontend`)

When the template is `frontend`, also generate one Next.js App Router catch-all route handler per backend service the frontend talks to. This keeps the browser on same-origin URLs and avoids `NEXT_PUBLIC_*` / runtime-config injection.

For each backend `<service>` create `ui/src/app/api/<service>/[...path]/route.ts` exporting `GET`, `POST`, `PUT`, `PATCH`, `DELETE` that:

- Read `process.env.<SERVICE>_URL` (server-only — populated by the frontend's `docker.env` in Step 7).
- Build `proxyURL = new URL(path.join('/') + request.nextUrl.search, UPSTREAM)`.
- Forward via `fetch(new Request(proxyURL, request))` inside `try/catch`.
- On `fetch` failure return HTTP 502 with a structured JSON error body (`{ error, service, detail }`).
- If `<SERVICE>_URL` is unset, return HTTP 502 with `error: "upstream_not_configured"`.

Then update the frontend's repository classes (`Http<Service>Repository` and similar) to call `/api/<service>/...` (same origin) and remove every `NEXT_PUBLIC_*_URL` reference plus any `window.__RUNTIME_CONFIG__` injection. The detailed code template lives in the `monitor-and-scaffold` and `scaffold-project` prompts — emit the same shape here so ad-hoc `/scaffold-services <name> frontend ...` runs match the cron flow.

## Port Convention

Backend guest ports start at `8001` and increment per service. The frontend uses guest port `3000`. Host ports are `${PORT_PREFIX}<guest>` where `${PORT_PREFIX}` is the single-digit value of `POIESIS_HOST_PORT_PREFIX` (default `3`). For example, with the default prefix, guest `8001` maps to host `38001` and guest `3000` maps to host `33000`.
