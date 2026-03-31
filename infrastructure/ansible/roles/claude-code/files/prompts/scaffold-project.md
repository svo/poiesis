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
```

For frontend services use `svo/www-qual-is` instead.

Add each as a submodule:

```bash
git submodule add git@github.com:${GITHUB_OWNER}/${PROJECT_NAME}-${service}.git services/${service}
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

## Step 6: Create Specification

Use `/specify` to create an initial feature spec for the project's core functionality in `.specs/initial/SPEC.md`.

## Step 7: Create Implementation Plan

Use `/plan initial` to produce the implementation plan from the spec.

## Step 8: Implement

Work through the plan's task list, implementing each task, running tests, and committing as you go.

Commit the scaffold with: `chore: scaffold ${PROJECT_NAME} with service submodules`
