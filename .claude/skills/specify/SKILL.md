---
name: specify
description: Defines feature specifications for Poiesis using spec-driven development. Produces structured requirements with user stories, acceptance criteria, and scaffolding-pipeline impacts. Use when the user describes a new feature, enhancement, or behaviour change. Inspired by GitHub spec-kit methodology.
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep
---

# Specify

Define feature specifications before implementation. Requirements are fully articulated before any code is written.

## Usage

`/specify <feature-description>`

## Process

1. **Read the platform CLAUDE.md** to understand current architecture and behaviour.

2. **Identify affected surfaces** — which of these does the feature touch?
   - OpenClaw configuration (`infrastructure/ansible/roles/openclaw/`, generated workspace files)
   - Claude Code configuration (`infrastructure/ansible/roles/claude-code*`)
   - Entrypoint / workspace-file generation
   - Packer image definitions (`infrastructure/packer/*.pkr.hcl`) and Ansible playbooks
   - Build and release scripts (`build.sh`, `push.sh`, `create-latest.sh`, `bin/*`)
   - Runtime environment variables (`POIESIS_*`, auth tokens, messaging tokens)
   - Scaffolding behaviour — what gets created under `POIESIS_GITHUB_OWNER` and how

3. **Produce a specification document** saved to `.specs/<feature-name>/SPEC.md`:

```markdown
# Feature: <name>

## Overview
One-paragraph summary of the feature and its value.

## User Stories
- As a <role>, I want <goal> so that <benefit>

## Acceptance Criteria
- [ ] Given <context>, when <action>, then <outcome>

## Surface Impact
Which of the surfaces above are affected and how.

## Environment & Configuration
New or changed environment variables, workspace-file content, OpenClaw/Claude Code settings.

## Scaffolding Behaviour Impact
Does this change what gets scaffolded into new repos, or when/how scaffolding runs? Describe the resulting repo shape.

## Operational Impact
Cron schedule, image size, startup time, persisted state under `/root/.openclaw`, messaging channels.

## Constraints
Verify against the "What Not to Build" rules in the platform CLAUDE.md.

## Open Questions
List any ambiguities or decisions that need resolution.
```

4. **Cross-reference** the spec against existing specs in `.specs/` for consistency and conflicts.

5. Present the spec for review before proceeding to `/plan`.

## Additional resources

- Platform overview: [parent CLAUDE.md](../../CLAUDE.md)
- Existing specs: `.specs/`
