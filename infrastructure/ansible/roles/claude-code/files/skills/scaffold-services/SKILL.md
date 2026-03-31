---
name: scaffold-services
description: Creates new service repositories from templates and adds them as git submodules. Handles repo creation from svo/python-sprint-zero or svo/www-qual-is templates, template reference renaming, port assignment, Vagrantfile updates, and CLAUDE.md configuration.
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
- `$2`: Port number (host port will have a `2` prefix, e.g. `8001` -> `28001`)
- `$3`: One-line description of the service

## Steps

1. **Read the project's CLAUDE.md** to determine the GitHub owner and project name.

2. **Create the GitHub repo from template:**

```bash
gh repo create ${GITHUB_OWNER}/${PROJECT_NAME}-$0 --template svo/$1-sprint-zero --private
```

For frontend template use `svo/www-qual-is` instead.

3. **Add as submodule:**

For backend services:
```bash
git submodule add git@github.com:${GITHUB_OWNER}/${PROJECT_NAME}-$0.git services/$0
```

For frontend:
```bash
git submodule add git@github.com:${GITHUB_OWNER}/${PROJECT_NAME}-$0.git ui
```

4. **Rename template references** (Python services only):

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

5. **Update Vagrantfile** — add the port mapping:

```ruby
config.vm.network "forwarded_port", guest: $2, host: 2$2  # $0
```

6. **Update the service's `.claude/CLAUDE.md`** — add a `## Project Purpose` section with `### Core Domain Concepts` subsection after the top-level title. Include the port assignment and service description.

7. **Verify the docker-tag** in `infrastructure/packer/service.pkr.hcl` reflects the new service name.

8. **Commit and push** the submodule changes, then update the parent repo's submodule reference.

## Port Convention

Backend services start at port 8001 and increment. Frontend uses port 3000. Host-mapped ports have a `2` prefix (e.g. 8001 -> 28001, 3000 -> 23000).
