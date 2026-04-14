You are scaffolding a new software project based on a blog post concept. The blog post has been analysed and the project concept extracted into CLAUDE.md in this repository.

Read CLAUDE.md to understand the project concept, then follow this process:

## Step 1: Decompose into Services

Using sequential thinking, analyse the concept and decompose it into discrete services. For each service determine:

- **Name** (kebab-case, e.g. `event-processor`)
- **Type** — `backend` (uses `svo/python-sprint-zero` template) or `frontend` (uses `svo/www-qual-is` template)
- **Port** — assign sequentially starting at 8001 for backends, 3000 for frontend
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

Add each as a submodule:

```bash
git submodule add https://github.com/${GITHUB_OWNER}/${PROJECT_NAME}-${service}.git services/${service}
```

Frontend goes under `ui/` instead of `services/`.

## Step 3: Rename Template References

For Python services, rename all template references in three forms:

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

## Step 4: Configure Ports and Networking

Create or update a Vagrantfile with port mappings for all services:

```ruby
Vagrant.configure("2") do |config|
  # Port mappings — host port has a "2" prefix
  config.vm.network "forwarded_port", guest: XXXX, host: 2XXXX  # service-name
end
```

For frontend services, configure environment variables pointing to each backend's host-mapped port:

```
NEXT_PUBLIC_<SERVICE_NAME>_URL=http://localhost:2XXXX
```

## Step 5: Update CLAUDE.md Files

For each service, update `.claude/CLAUDE.md` by adding after the top-level title:

```markdown
## Project Purpose

<Service's role within the project and its assigned port.>

### Core Domain Concepts

<Key domain entities and behaviours this service owns.>
```

Verify each service's `docker-tag` in `infrastructure/packer/service.pkr.hcl` reflects the new service name.

## Step 6: Create Project Skills

The new project repository needs its own Claude Code skills so that anyone working in it has project-aware tooling. Read each skill from `/home/claude/.claude/skills/` and create an adapted version in the new project's `.claude/skills/<skill-name>/SKILL.md`.

For each skill:

1. Read the source SKILL.md from `/home/claude/.claude/skills/<skill-name>/SKILL.md`
2. Preserve the frontmatter structure (name, description, allowed-tools, etc.)
3. Adapt the body as described below
4. Write to `.claude/skills/<skill-name>/SKILL.md` in the project repository

### Generic skills — copy without modification

These skills are project-agnostic. Copy them verbatim:

- `sequential-thinking`
- `specify`
- `plan`

### Skills requiring adaptation

Adapt these skills to reference the concrete services, ports, and structure created in the preceding steps:

- **`run-service`** — replace generic references with the actual service names, ports (from Step 4), and docker-tags (from each service's `infrastructure/packer/service.pkr.hcl`).

- **`health-check`** — populate the expected services and ports based on the services created in Step 2 and ports assigned in Step 4.

- **`explore-architecture`** — reference the actual `services/` and `ui/` directories and the domain concepts identified in Step 1.

- **`scaffold-services`** — set the GitHub owner and project name from CLAUDE.md. Set the next available port based on ports already assigned in Step 4.

- **`add-integration`** — reference the actual service names and which service handles what role based on the decomposition from Step 1.

- **`shared-schema`** — name the actual services and the data structures they share based on the domain concepts from Step 1.

## Step 7: Create Specification

Use `/specify` to create an initial feature spec for the project's core functionality in `.specs/initial/SPEC.md`.

## Step 8: Create Implementation Plan

Use `/plan initial` to produce the implementation plan from the spec.

## Step 9: Implement

Work through the plan's task list, implementing each task, running tests, and committing as you go.

Commit the scaffold with: `chore: scaffold ${PROJECT_NAME} with service submodules`
