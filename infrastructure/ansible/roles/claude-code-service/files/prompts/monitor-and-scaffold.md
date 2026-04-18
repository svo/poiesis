You are running a scheduled pipeline that monitors a blog for software project concepts, scaffolds GitHub repositories from them, and builds the initial implementation.

## Environment

Read these from your environment and from the workspace `AGENTS.md`:

```bash
echo "BLOG_URL=$POIESIS_BLOG_URL"
echo "GITHUB_OWNER=$POIESIS_GITHUB_OWNER"
```

Read the host-port prefix from `AGENTS.md` (single digit `1`–`9`, default `3`). Use it as `${PORT_PREFIX}` for every host-mapped port you assign in the Vagrantfile and in any document that references those ports. Do not read it from `process.env` — `AGENTS.md` is the source of truth for scaffold-time configuration.

## Step 1: Fetch and Analyse the Blog

Fetch the blog at the URL above. Identify any posts that describe a concrete software project concept. A post qualifies if it:

- Describes a concrete software product, tool, library, or architectural pattern
- Names or implies a specific problem that software could address
- Proposes an interface, protocol, or system design — even speculatively

Skip posts that are purely philosophical or reflective without a concrete software concept.

## Step 2: Check for New Concepts

For each qualifying post, derive a short, lowercase kebab-case project name from the concept (e.g. a post about "perception-aware interfaces" becomes `perception-aware-interfaces`).

Check if a repository already exists under the GitHub owner:

```bash
gh repo view ${GITHUB_OWNER}/${project-name} 2>/dev/null && echo "EXISTS" || echo "NEW"
```

If the repository already exists, skip it. Only proceed with new concepts.

If there are no new qualifying concepts, output `NO_NEW_PROJECTS` and stop.

## Step 3: Create and Seed the Repository

For each new concept, create and seed the repository:

```bash
gh repo create ${GITHUB_OWNER}/${project-name} --private \
  --description "<description from blog post>"
gh api repos/${GITHUB_OWNER}/${project-name}/actions/permissions --method PUT -F enabled=false
```

Clone the repository and seed it with:

- **README.md** — project name, description, philosophical motivation (linked to the blog post), key architectural ideas, and a "Getting Started" placeholder
- **LICENSE** — MIT
- **CLAUDE.md** — project name (kebab-case), title, GitHub owner, purpose and motivation summarised from the blog post, link to the originating post, key architectural decisions or constraints, technology suggestions if implied, and a note that this project was scaffolded by Poiesis
- **.gitignore** — at minimum:
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

Commit and push: `chore: seed ${project-name} from blog post`

## Step 4: Decompose into Services

Using sequential thinking, analyse each concept and decompose it into discrete services. For each service determine:

- **Name** (kebab-case, e.g. `event-processor`)
- **Type** — `backend` (uses `svo/python-sprint-zero` template) or `frontend` (uses `svo/www-qual-is` template)
- **Port** — guest port assigned sequentially starting at 8001 for backends, 3000 for frontend
- **Purpose** — one-line description of the service's role
- **Core domain concepts** — key entities and behaviours the service owns

Not every project needs microservices. A simple tool or library may be a single service or no services at all. Match the architecture to the problem.

## Step 5: Create Service Repositories

For each service, create a GitHub repo from the appropriate template:

```bash
gh repo create ${GITHUB_OWNER}/${project-name}-${service} \
  --template svo/python-sprint-zero --private
gh api repos/${GITHUB_OWNER}/${project-name}-${service}/actions/permissions --method PUT -F enabled=false
```

For frontend services use `svo/www-qual-is` instead.

**Do not remove `.github/workflows` from any service repository.** The workflows are disabled at the repo level and will be re-enabled later.

Add each as a submodule using the `https://github.com/...` form. The entrypoint rewrites `git@github.com:` to HTTPS so tokens never end up in `.gitmodules`; any submodule added with an SSH URL will break that contract.

```bash
git submodule add https://github.com/${GITHUB_OWNER}/${project-name}-${service}.git services/${service}
```

Frontend goes under `ui/` instead of `services/`. Choose the path on the first add — there is no need to rename it later.

## Step 6: Purge Template Scaffolding

Immediately after each `git submodule add`, before any renaming or editing, run the purge skill:

```bash
# Backend service
/purge-template python-sprint-zero services/${service}

# Frontend
/purge-template www-qual-is ui
```

This removes demo entities (Coconut), template content (blog posts, blog routes), template-only features (basic auth, unless the concept explicitly requires per-service auth), and known template defects (`application.properties` newline). The skill verifies its own work and fails loudly if residue remains.

## Step 7: Rename Template References

For Python services, rename all template references in three forms:

```bash
underscore=$(echo ${service} | tr '-' '_')
titlecase=$(echo ${service} | sed 's/-/ /g' | sed 's/\b\w/\u&/g')

# File contents
fgrep -rl python-sprint-zero . | xargs sed -i "s/python-sprint-zero/${project-name}-${service}/g"
fgrep -rl python_sprint_zero . | xargs sed -i "s/python_sprint_zero/${project-name//-/_}_${underscore}/g"
fgrep -rl "Python Sprint Zero" . | xargs sed -i "s/Python Sprint Zero/${project-title} ${titlecase}/g"

# File and directory names (depth-first)
find . -depth -name "*python_sprint_zero*" | while read f; do
  mv "$f" "$(echo $f | sed "s/python_sprint_zero/${project-name//-/_}_${underscore}/g")"
done
find . -depth -name "*python-sprint-zero*" | while read f; do
  mv "$f" "$(echo $f | sed "s/python-sprint-zero/${project-name}-${service}/g")"
done
```

## Step 8: Wire Frontend Backend URLs via API Proxy Routes

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
- The Vagrantfile (Step 9) supplies `<SERVICE>_URL` as a server-only env var on the frontend container.

## Step 9: Configure Ports and Networking

Generate a Vagrantfile in the parent repo using the **Docker provider** with one `config.vm.define` block per service. Use `${PORT_PREFIX}` (from `AGENTS.md`) as the host-port prefix; guest ports come from each service's assignment in Step 4.

```ruby
Vagrant.configure("2") do |config|
  config.vm.define "<backend-service>" do |s|
    s.vm.provider :docker do |d|
      d.image = "${GITHUB_OWNER}/${project-name}-<backend-service>-service:latest"
      d.name  = "${project-name}-<backend-service>"
      d.ports = ["${PORT_PREFIX}XXXX:XXXX"]   # ${PORT_PREFIX}XXXX on host -> XXXX in container
      d.env   = {
        "APP_<OTHER_BACKEND>_URL" => "http://host.docker.internal:${PORT_PREFIX}YYYY"
      }
    end
  end

  config.vm.define "<frontend>" do |s|
    s.vm.provider :docker do |d|
      d.image = "${GITHUB_OWNER}/${project-name}-<frontend>-service:latest"
      d.name  = "${project-name}-<frontend>"
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
- Frontend backend URLs are server-only env vars (`<SERVICE>_URL`) — never `NEXT_PUBLIC_*`. They are read inside the API route handlers from Step 8.
- Every host port uses `${PORT_PREFIX}` resolved at scaffold time.

## Step 10: Update CLAUDE.md Files and Docker Tags

For each service, update `.claude/CLAUDE.md` by adding after the top-level title:

```markdown
## Project Purpose

<Service's role within the project and its assigned guest port and host port (with ${PORT_PREFIX}).>

### Core Domain Concepts

<Key domain entities and behaviours this service owns.>
```

Edit `infrastructure/packer/service.pkr.hcl` in each service so that `docker-tag` is exactly `${GITHUB_OWNER}/${project-name}-${service}-service`. This applies to **both** backend and frontend services — the frontend tag must not contain `www-qual-is`.

Then update the parent `CLAUDE.md`, `README.md`, and (later) `.specs/initial/SPEC.md` so every host-port reference matches the resolved `${PORT_PREFIX}` and every image name matches the canonical docker-tag. The parent docs and the Vagrantfile must agree.

## Step 11: Create Specification

Use `/specify` to create an initial feature spec for the project's core functionality in `.specs/initial/SPEC.md`. Reference the host ports using the resolved prefix.

## Step 12: Create Implementation Plan

Use `/plan initial` to produce the implementation plan from the spec. The generated plan must open with a "Phase 0: Template tear-out" section that documents the purge already performed (so the human reviewer sees the work as first-class) and must include a coverage table mapping every spec acceptance criterion to at least one task.

## Step 13: Implement

Work through the plan's task list, implementing each task, running tests, and committing as you go.

Commit the scaffold with: `chore: scaffold ${project-name} with service submodules`

## Step 14: Output Summary

After all projects are scaffolded, output a summary for each in this format:

```
NEW_PROJECT: ${project-name}
BLOG_POST: <url of the originating blog post>
REPO: https://github.com/${GITHUB_OWNER}/${project-name}
DESCRIPTION: <brief description of the concept and what was implemented>
```

This summary will be used by the orchestrator to notify via messaging channels.
