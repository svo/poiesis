---
name: plan
description: Creates a technical implementation plan from a feature specification. Produces a step-by-step plan with tasks, identifies coordination points, and generates an ordered task list with explicit Phase 0 template tear-out and a spec-criterion-to-task coverage table. Use after /specify has produced a SPEC.md.
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

## Phase 0: Template tear-out

The first phase of every initial scaffold plan. List the template-purge work
that the scaffolder performs (or has already performed) per service template,
making it visible to the human reviewer rather than implicit. Include only the
items that apply to the services in this project:

- **Demo-entity removal** — for backends scaffolded from `svo/python-sprint-zero`,
  remove the Coconut domain model, repository, controller, DTO, and tests across
  every backend.
- **Template-content removal** — for frontends scaffolded from `svo/www-qual-is`,
  remove `_posts/`, blog routes (`src/app/blog`, `src/app/posts`, `src/app/about`,
  `src/app/feed.xml`, `src/app/sitemap.ts`), blog application/domain/infrastructure
  layers (`PostService`, `IPostRepository`, `FileSystemPostRepository`,
  `InMemoryPostRepository`, post interfaces, markdown helpers), blog-only public
  assets, and blog-specific e2e specs.
- **Template-bug fixes** — for backends, ensure `src/*/resources/application.properties`
  has `host` and `port` on separate lines.
- **Template-only feature removal** — for backends, remove basic-auth wiring
  unless the spec explicitly calls for per-service auth.
- **Brand-name purge** — for frontends, strip residual `qual.is` /
  `www-qual-is` references except any explicitly retained attribution.

For follow-on (non-initial) feature plans, omit Phase 0 if no template tear-out
is in scope.

## Phase 1+: Feature work

### <module-or-layer>
- What changes and why
- New files or modified files
- New/modified interfaces or endpoints

(Repeat per affected area / per service.)

## Task List

Ordered list of implementation tasks. Each task should be independently committable.

1. [ ] <area>: <task description>
2. [ ] <area>: <task description>
...

## Spec Coverage

| SPEC criterion | Task(s) |
|---|---|
| <verbatim acceptance criterion from SPEC.md> | <task numbers> |
| ... | ... |

## Testing Strategy
- Unit tests
- Integration tests
- End-to-end tests (if applicable)

## Risks and Mitigations
- Risk: <description> -> Mitigation: <approach>
```

4. **Validate** the plan against the spec — confirm all acceptance criteria are covered by at least one task.

4.5. **Coverage gate** — every acceptance criterion in `.specs/$0/SPEC.md` must map to at least one task in the generated `PLAN.md`. If a criterion is unmapped, the plan is incomplete: either add a task for it or document in `## Open Questions` why it is intentionally deferred. Emit the coverage table at the bottom of `PLAN.md` (as shown in the structure above) listing every spec criterion against the task numbers that satisfy it.

5. Present the plan for review before implementation.
