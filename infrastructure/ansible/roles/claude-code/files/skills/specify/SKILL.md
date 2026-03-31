---
name: specify
description: Defines feature specifications using spec-driven development. Produces structured requirements with user stories, acceptance criteria, and domain model impacts. Use when the project needs a clear feature definition before implementation.
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep
---

# Specify

Define feature specifications before implementation. This follows a spec-driven development approach where requirements are fully articulated before any code is written.

## Usage

`/specify <feature-description>`

## Process

1. **Read the project's CLAUDE.md** to understand the current architecture and domain concepts.

2. **Identify affected areas** — which parts of the codebase will this feature touch?

3. **Produce a specification document** saved to `.specs/<feature-name>/SPEC.md` with this structure:

```markdown
# Feature: <name>

## Overview
One-paragraph summary of the feature and its value.

## User Stories
- As a <role>, I want <goal> so that <benefit>
- ...

## Acceptance Criteria
- [ ] Given <context>, when <action>, then <outcome>
- ...

## Domain Model Impact
Which core domain concepts are affected? Are new entities needed?
List affected modules and what changes in each.

## API Contracts
Define any new or modified endpoints or interfaces.
Include request/response shapes where applicable.

## Open Questions
List any ambiguities or decisions that need resolution.
```

4. **Cross-reference** the spec against existing specs in `.specs/` for consistency and conflicts.

5. Present the spec for review before proceeding to `/plan`.
