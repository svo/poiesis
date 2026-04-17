---
name: plan
description: Creates a technical implementation plan from a Poiesis feature specification. Produces a step-by-step task list grouped by surface (Ansible roles, workspace files, entrypoint, Packer images, scripts). Use after /specify has produced a SPEC.md. Inspired by GitHub spec-kit /plan methodology.
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep
---

# Plan

Create a technical implementation plan from a feature specification. Bridges the "what" (the spec) to the "how" (the code).

## Usage

`/plan <spec-name>`

Where `<spec-name>` matches a directory under `.specs/`.

## Process

1. **Read the spec** at `.specs/<spec-name>/SPEC.md`.

2. **Read the platform CLAUDE.md** and the relevant subset of:
   - `infrastructure/ansible/roles/openclaw/`, `claude-code/`, `claude-code-service/`
   - `infrastructure/ansible/playbook-service.yml` (or `-development.yml` / `-builder.yml` if relevant)
   - `infrastructure/packer/service.pkr.hcl`
   - Entrypoint and workspace-file generation logic

3. **Produce a plan document** at `.specs/<spec-name>/PLAN.md`:

```markdown
# Plan: <feature-name>

## Implementation Strategy
High-level approach and key decisions.

## Surface Changes

### OpenClaw configuration
- Role / workspace-file / setting changes

### Claude Code configuration
- Role / workspace-file / setting changes

### Entrypoint & workspace generation
- New env vars consumed, new workspace files written, startup-check changes

### Packer images
- Which images rebuild; any new installed packages or base changes

### Build & release scripts
- Changes to `build.sh` / `push.sh` / `create-latest.sh` / `bin/*`

### Runtime environment
- New or changed `POIESIS_*` / auth / messaging variables and their validation

## Task List

Ordered, independently committable tasks.

1. [ ] <surface>: <task>
2. [ ] <surface>: <task>

## Testing Strategy
- Lint: `shellcheck`, `ansible-lint`, `semgrep`
- Local dev: rebuild the relevant image and exercise via `vagrant up` or `docker run`
- End-to-end: trigger a scaffolding run against a throwaway GitHub target

## Risks & Mitigations
- Risk: <description> → Mitigation: <approach>
```

4. **Validate** the plan — confirm every acceptance criterion in the spec is covered by at least one task.

5. **Validate operational constraints** — no task should introduce state outside `/root/.openclaw`, bypass the workspace-file mechanism, or fracture the single-container model. See "What Not to Build" in the platform CLAUDE.md.

6. Present the plan for review before implementation.

## Additional resources

- Source spec: `.specs/<spec-name>/SPEC.md`
- Platform architecture: [parent CLAUDE.md](../../CLAUDE.md)
