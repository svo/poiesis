---
name: plan
description: Creates a technical implementation plan from a feature specification. Produces a step-by-step plan with tasks, identifies coordination points, and generates an ordered task list. Use after /specify has produced a SPEC.md.
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep
---

# Plan

Create a technical implementation plan from a feature specification. This bridges the gap between "what" (the spec) and "how" (the code).

## Usage

`/plan <spec-name>`

Where `<spec-name>` matches a directory under `.specs/`.

## Process

1. **Read the spec** at `.specs/$0/SPEC.md`.

2. **Read the project's CLAUDE.md** to understand conventions and architecture.

3. **Produce a plan document** saved to `.specs/$0/PLAN.md` with this structure:

```markdown
# Plan: <feature-name>

## Implementation Strategy
High-level approach and key architectural decisions.

## Changes

### <module-or-layer>
- What changes and why
- New files or modified files
- New/modified interfaces or endpoints

(Repeat for each affected area)

## Task List

Ordered list of implementation tasks. Each task should be independently committable.

1. [ ] <area>: <task description>
2. [ ] <area>: <task description>
...

## Testing Strategy
- Unit tests
- Integration tests
- End-to-end tests (if applicable)

## Risks and Mitigations
- Risk: <description> -> Mitigation: <approach>
```

4. **Validate** the plan against the spec — confirm all acceptance criteria are covered by at least one task.

5. Present the plan for review before implementation.
