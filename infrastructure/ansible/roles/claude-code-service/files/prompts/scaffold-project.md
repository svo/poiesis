You are scaffolding a new software project based on a blog post concept. The blog post has been analysed and the project concept extracted into CLAUDE.md in this repository.

Read CLAUDE.md to understand the project concept, then follow this process.

Read two settings from the environment, print them once, and use these values for the whole run:

```bash
echo "PORT_PREFIX=${POIESIS_HOST_PORT_PREFIX:-3}"
echo "IMAGE_NAMESPACE=${POIESIS_IMAGE_NAMESPACE:-$GITHUB_OWNER}"
```

- `${PORT_PREFIX}` (single digit `1`–`9`, default `3`) prefixes every host-mapped port you assign in the Vagrantfile and in any document that references those ports.
- `${IMAGE_NAMESPACE}` (default: the GitHub owner from CLAUDE.md) is the registry namespace for every image name: `docker-tag` repositories and Vagrantfile images. GitHub repositories live under `${GITHUB_OWNER}`; images live under `${IMAGE_NAMESPACE}`. The two can differ.

## Step 1: Decompose into Services

Using sequential thinking, analyse the concept and decompose it into discrete services. For each service determine:

- **Name** (kebab-case, e.g. `event-processor`)
- **Type** — `backend` (uses `svo/python-sprint-zero` template) or `frontend` (uses `svo/www-qual-is` template)
- **Port** — guest port assigned sequentially starting at 8001 for backends, 3000 for frontend
- **Purpose** — one-line description of the service's role
- **Core domain concepts** — key entities and behaviours the service owns

Not every project needs microservices. A simple tool or library may be a single service or no services at all. Match the architecture to the problem.

## Step 2: Create Service Repositories

For each service, create a GitHub repo from the appropriate template:

```bash
gh repo create ${GITHUB_OWNER}/${PROJECT_NAME}-${service} \
  --template svo/python-sprint-zero --private
gh api repos/${GITHUB_OWNER}/${PROJECT_NAME}-${service}/actions/permissions --method PUT -F enabled=false
```

For frontend services use `svo/www-qual-is` instead.

**Do not remove `.github/workflows` from any service repository.** The workflows are disabled at the repo level and will be re-enabled later.

Add each as a submodule using the `https://github.com/...` form. The entrypoint rewrites `git@github.com:` to HTTPS so tokens never end up in `.gitmodules`; any submodule added with an SSH URL will break that contract.

```bash
git submodule add https://github.com/${GITHUB_OWNER}/${PROJECT_NAME}-${service}.git services/${service}
```

Frontend goes under `ui/` instead of `services/`. Choose the path on the first add — there is no need to rename it later.

While in the parent repo, ensure `.gitignore` includes (creating it if missing):

```gitignore
.vagrant/
.DS_Store
node_modules/
__pycache__/
*.py[cod]
.pytest_cache/
.tox/
.coverage
```

## Step 3: Purge Template Scaffolding

Immediately after each `git submodule add`, before any renaming or editing, invoke the `purge-template` skill with the template and the submodule path:

```
/purge-template python-sprint-zero services/${service}   # backend
/purge-template www-qual-is ui                          # frontend
```

This removes demo entities (Coconut), template content (blog posts, blog routes), template-only features (basic auth, unless the concept explicitly requires per-service auth), and ends `application.properties` with a newline. For a backend the skill finishes by running `poiesis-purge-check python-sprint-zero .`; the frontend check runs after Step 4, once the template name has been replaced.

## Step 4: Rename Template References and Set the Port

Work inside the submodule (`cd services/${service}` or `cd ui`).

### Backend (`python-sprint-zero`)

Rename all template references in three forms:

```bash
underscore=$(echo ${service} | tr '-' '_')
titlecase=$(echo ${service} | sed 's/-/ /g' | sed 's/\b\w/\u&/g')

# File contents
fgrep -rl python-sprint-zero . | xargs sed -i "s/python-sprint-zero/${PROJECT_NAME}-${service}/g"
fgrep -rl python_sprint_zero . | xargs sed -i "s/python_sprint_zero/${PROJECT_NAME//-/_}_${underscore}/g"
fgrep -rl "Python Sprint Zero" . | xargs sed -i "s/Python Sprint Zero/${PROJECT_TITLE} ${titlecase}/g"

# File and directory names (depth-first)
find . -depth -name "*python_sprint_zero*" | while read f; do
  mv "$f" "$(echo $f | sed "s/python_sprint_zero/${PROJECT_NAME//-/_}_${underscore}/g")"
done
find . -depth -name "*python-sprint-zero*" | while read f; do
  mv "$f" "$(echo $f | sed "s/python-sprint-zero/${PROJECT_NAME}-${service}/g")"
done
```

Then write the service's guest port from Step 1 into `application.properties` as a line of its own. The purge left the file ending in a newline, so append; never edit the `host` line:

```bash
props=$(find src -path '*/resources/application.properties')
sed -i '/^port=/d' "$props"
printf 'port=%s\n' "${guest_port}" >> "$props"
```

### Frontend (`www-qual-is`)

Replace the template name with `${PROJECT_NAME}-${service}` in file contents and in file and directory names:

```bash
fgrep -rl www-qual-is . | xargs sed -i "s/www-qual-is/${PROJECT_NAME}-${service}/g"
find . -depth -name "*www-qual-is*" | while read f; do
  mv "$f" "$(echo $f | sed "s/www-qual-is/${PROJECT_NAME}-${service}/g")"
done
```

Then rewrite each remaining `qual.is` reference in context. Never delete the text with `sed`:

- **Site URL** — `https://www.qual.is` in `metadataBase`, canonical and Open Graph URLs, JSON-LD and `src/lib/constants.ts`: read a `SITE_URL` setting that defaults to `http://localhost:${PORT_PREFIX}3000`.
- **Brand text** — `qual.is` in the navigation, footer, page titles, `not-found`, the web manifest, `README.md` and `run.sh`: the project title.
- **Analytics** — remove the analytics script from `src/app/layout.tsx` and its entries in the content-security-policy in `next.config.js`.
- **`public/robots.txt`** — disallow everything (`User-agent: *`, `Disallow: /`) and drop the `Sitemap:` line.
- **Contact address** — remove the `mailto:` link to a `qual.is` address.
- **Template reference notes** under `.claude/skills/*/references/` that quote the blog's code: delete them.
- Update the tests that assert on any of the above.

If a reference must stay on purpose (for example a licence attribution), list its path, relative to the submodule root, in `.purge-allow`, one per line. The check prints every path that file allows.

### Check before pushing

From the parent repo, run the residue check for every submodule once its rename and port are done, before its first push:

```bash
poiesis-purge-check python-sprint-zero services/${service}   # each backend
poiesis-purge-check www-qual-is ui                          # frontend
```

It names each file that still carries template residue and exits non-zero. Fix what it names and run it again. Do not push a submodule, or the parent's reference to it, until its check exits 0.

## Step 5: Wire Frontend Backend URLs via API Proxy Routes

For the frontend submodule, generate a Next.js App Router catch-all route handler per backend service so the browser only ever talks to same-origin URLs. This avoids CORS, runtime-config injection, and `NEXT_PUBLIC_*` build-time bindings.

For each backend service `<service>`, create `ui/src/app/api/<service>/[...path]/route.ts`:

```typescript
import { NextRequest } from 'next/server'

const UPSTREAM = process.env.<SERVICE>_URL

async function proxy(
  request: NextRequest,
  ctx: { params: Promise<{ path: string[] }> },
) {
  if (!UPSTREAM) {
    return Response.json(
      { error: 'upstream_not_configured', service: '<service>' },
      { status: 502 },
    )
  }
  const { path } = await ctx.params
  const proxyURL = new URL(
    `${path.join('/')}${request.nextUrl.search}`,
    UPSTREAM,
  )
  try {
    return await fetch(new Request(proxyURL, request))
  } catch (reason) {
    const message =
      reason instanceof Error ? reason.message : 'unexpected_exception'
    return Response.json(
      { error: 'upstream_unreachable', service: '<service>', detail: message },
      { status: 502 },
    )
  }
}

export const GET = proxy
export const POST = proxy
export const PUT = proxy
export const PATCH = proxy
export const DELETE = proxy
```

Then:

- Update the frontend's repository classes (`Http<Service>Repository` and similar) to call same-origin paths: `fetch('/api/<service>/...')`.
- Remove every `NEXT_PUBLIC_*_URL` reference from the frontend.
- Remove any `window.__RUNTIME_CONFIG__` runtime-config injection scaffolded by the template.
- The Vagrantfile (Step 6) supplies `<SERVICE>_URL` as a server-only env var on the frontend container.

## Step 6: Configure Ports and Networking

Generate a Vagrantfile in the parent repo using the **Docker provider** with one `config.vm.define` block per service. Use `${PORT_PREFIX}` (from the environment) as the host-port prefix and `${IMAGE_NAMESPACE}` for every image; guest ports come from each service's assignment in Step 1.

```ruby
Vagrant.configure("2") do |config|
  config.vm.define "<backend-service>" do |s|
    s.vm.provider :docker do |d|
      d.image = "${IMAGE_NAMESPACE}/${PROJECT_NAME}-<backend-service>-service:latest"
      d.name  = "${PROJECT_NAME}-<backend-service>"
      d.ports = ["${PORT_PREFIX}XXXX:XXXX"]   # ${PORT_PREFIX}XXXX on host -> XXXX in container
      d.env   = {
        "APP_<OTHER_BACKEND>_URL" => "http://host.docker.internal:${PORT_PREFIX}YYYY"
      }
    end
  end

  config.vm.define "<frontend>" do |s|
    s.vm.provider :docker do |d|
      d.image = "${IMAGE_NAMESPACE}/${PROJECT_NAME}-<frontend>-service:latest"
      d.name  = "${PROJECT_NAME}-<frontend>"
      d.ports = ["${PORT_PREFIX}3000:3000"]
      d.env   = {
        "<BACKEND_A>_URL" => "http://host.docker.internal:${PORT_PREFIX}XXXX",
        "<BACKEND_B>_URL" => "http://host.docker.internal:${PORT_PREFIX}YYYY"
      }
    end
  end
end
```

Rules:

- One `config.vm.define` per service. No single-VM `config.vm.network "forwarded_port"` style.
- Backend-to-backend wiring uses `APP_<OTHER>_URL` server-only env vars routed through `host.docker.internal` and the host-mapped port.
- Frontend backend URLs are server-only env vars (`<SERVICE>_URL`) — never `NEXT_PUBLIC_*`. They are read inside the API route handlers from Step 5.
- Every host port uses `${PORT_PREFIX}` resolved at scaffold time.
- Every image is `${IMAGE_NAMESPACE}/${PROJECT_NAME}-<service>-service:latest`.

## Step 7: Update CLAUDE.md Files and Docker Tags

For each service, update `.claude/CLAUDE.md` by adding after the top-level title:

```markdown
## Project Purpose

<Service's role within the project and its assigned guest port and host port (with ${PORT_PREFIX}).>

### Core Domain Concepts

<Key domain entities and behaviours this service owns.>
```

Edit `infrastructure/packer/service.pkr.hcl` in each service so that `docker-tag` is exactly `${IMAGE_NAMESPACE}/${PROJECT_NAME}-${service}-service`. This applies to **both** backend and frontend services — the frontend tag must not contain `www-qual-is`.

The templates' other image names (the builder, development, mock and documentation repositories in `infrastructure/packer/*.pkr.hcl`, the root `*.sh` scripts and each service's own `Vagrantfile`) use the template's namespace, `svanosselaer/`. In each service, replace it with the configured one; nothing changes when the two are equal:

```bash
fgrep -rl 'svanosselaer/' infrastructure/packer ./*.sh Vagrantfile | xargs sed -i "s|svanosselaer/|${IMAGE_NAMESPACE}/|g"
```

Then update the parent `CLAUDE.md`, `README.md`, and (later) `.specs/initial/SPEC.md` so every host-port reference matches the resolved `${PORT_PREFIX}` and every image name matches the canonical docker-tag. The parent docs and the Vagrantfile must agree.

## Step 8: Create Project Skills

The new project repository needs its own Claude Code skills so that anyone working in it has project-aware tooling. Read each skill from `/home/claude/.claude/skills/` and create an adapted version in the new project's `.claude/skills/<skill-name>/SKILL.md`.

For each skill:

1. Read the source SKILL.md from `/home/claude/.claude/skills/<skill-name>/SKILL.md`
2. Preserve the frontmatter structure (name, description, allowed-tools, etc.), with one exception: the project copy of `scaffold-services` must carry `disable-model-invocation: true`, which the source does not. It creates repositories, so in a project only a person should start it.
3. Adapt the body as described below
4. Write to `.claude/skills/<skill-name>/SKILL.md` in the project repository

### Generic skills — copy without modification

These skills are project-agnostic. Copy them verbatim:

- `sequential-thinking`
- `specify`
- `plan`

### Skills requiring adaptation

Adapt these skills to reference the concrete services, ports, and structure created in the preceding steps:

- **`run-service`** — replace generic references with the actual service names (the `config.vm.define` names), host ports and images from the Vagrantfile (Step 6).

- **`health-check`** — populate the expected services and ports based on the services created in Step 2 and ports assigned in Step 6.

- **`explore-architecture`** — reference the actual `services/` and `ui/` directories and the domain concepts identified in Step 1.

- **`scaffold-services`** — set the GitHub owner and project name from CLAUDE.md. Set the next available port based on ports already assigned in Step 6. Write the resolved `${PORT_PREFIX}` and `${IMAGE_NAMESPACE}` into its Settings section in place of the environment lookups: a person running it in the project has no `POIESIS_*` variables. Add `disable-model-invocation: true` to its frontmatter.

- **`add-integration`** — reference the actual service names and which service handles what role based on the decomposition from Step 1.

- **`shared-schema`** — name the actual services and the data structures they share based on the domain concepts from Step 1.

## Step 9: Create Specification

Use `/specify` to create an initial feature spec for the project's core functionality in `.specs/initial/SPEC.md`. Reference the host ports using the resolved prefix.

## Step 10: Create Implementation Plan

Use `/plan initial` to produce the implementation plan from the spec. The generated plan must open with a "Phase 0: Template tear-out" section that documents the purge already performed (so the human reviewer sees the work as first-class) and must include a coverage table mapping every spec acceptance criterion to at least one task.

## Step 11: Implement

Work through the plan's task list, implementing each task, running tests, and committing as you go.

Commit the scaffold with: `chore: scaffold ${PROJECT_NAME} with service submodules`
