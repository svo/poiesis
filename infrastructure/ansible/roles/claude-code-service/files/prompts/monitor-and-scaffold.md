You are running a scheduled pipeline that monitors a blog for software project concepts, scaffolds GitHub repositories from them, and builds the initial implementation.

## Environment

Read these environment variables to configure your run:

```bash
echo "BLOG_URL=$POIESIS_BLOG_URL"
echo "GITHUB_OWNER=$POIESIS_GITHUB_OWNER"
```

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
```

Clone the repository and seed it with:

- **README.md** — project name, description, philosophical motivation (linked to the blog post), key architectural ideas, and a "Getting Started" placeholder
- **LICENSE** — MIT
- **CLAUDE.md** — project name (kebab-case), title, GitHub owner, purpose and motivation summarised from the blog post, link to the originating post, key architectural decisions or constraints, technology suggestions if implied, and a note that this project was scaffolded by Poiesis

Commit and push: `chore: seed ${project-name} from blog post`

## Step 4: Decompose into Services

Using sequential thinking, analyse each concept and decompose it into discrete services. For each service determine:

- **Name** (kebab-case, e.g. `event-processor`)
- **Type** — `backend` (uses `svo/python-sprint-zero` template) or `frontend` (uses `svo/www-qual-is` template)
- **Port** — assign sequentially starting at 8001 for backends, 3000 for frontend
- **Purpose** — one-line description of the service's role
- **Core domain concepts** — key entities and behaviours the service owns

Not every project needs microservices. A simple tool or library may be a single service or no services at all. Match the architecture to the problem.

## Step 5: Create Service Repositories

For each service, create a GitHub repo from the appropriate template:

```bash
gh repo create ${GITHUB_OWNER}/${project-name}-${service} \
  --template svo/python-sprint-zero --private
```

For frontend services use `svo/www-qual-is` instead.

Add each as a submodule:

```bash
git submodule add https://github.com/${GITHUB_OWNER}/${project-name}-${service}.git services/${service}
```

Frontend goes under `ui/` instead of `services/`.

## Step 6: Rename Template References

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

## Step 7: Configure Ports and Networking

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

## Step 8: Update CLAUDE.md Files

For each service, update `.claude/CLAUDE.md` by adding after the top-level title:

```markdown
## Project Purpose

<Service's role within the project and its assigned port.>

### Core Domain Concepts

<Key domain entities and behaviours this service owns.>
```

Verify each service's `docker-tag` in `infrastructure/packer/service.pkr.hcl` reflects the new service name.

## Step 9: Create Specification

Use `/specify` to create an initial feature spec for the project's core functionality in `.specs/initial/SPEC.md`.

## Step 10: Create Implementation Plan

Use `/plan initial` to produce the implementation plan from the spec.

## Step 11: Implement

Work through the plan's task list, implementing each task, running tests, and committing as you go.

Commit the scaffold with: `chore: scaffold ${project-name} with service submodules`

## Step 12: Output Summary

After all projects are scaffolded, output a summary for each in this format:

```
NEW_PROJECT: ${project-name}
BLOG_POST: <url of the originating blog post>
REPO: https://github.com/${GITHUB_OWNER}/${project-name}
DESCRIPTION: <brief description of the concept and what was implemented>
```

This summary will be used by the orchestrator to notify via messaging channels.
