---
name: explore-architecture
description: Explores the project architecture by reading CLAUDE.md files across all services and summarising the current state. Use when onboarding, understanding cross-service dependencies, or auditing the codebase.
context: fork
agent: Explore
allowed-tools: Read, Glob, Grep
---

# Explore Architecture

Produce a comprehensive overview of the current state of the project.

## Process

1. Read the parent `.claude/CLAUDE.md` for the project overview.

2. For each service under `services/` and `ui/`:
   - Read its `.claude/CLAUDE.md` for domain concepts and purpose
   - Check for API endpoint definitions (look for route/endpoint patterns)
   - Check for domain entities (look for classes/models in the domain layer)
   - Note any dependencies on other services

3. Produce a summary with:

   **Per-service status:**
   - Purpose and domain concepts
   - Key domain entities found in code
   - API endpoints exposed
   - Dependencies on other services
   - Test coverage status

   **Cross-service view:**
   - Service dependency graph (which services call which)
   - Shared contracts (schemas, types, protocols)
   - Potential architectural concerns (circular dependencies, missing contracts)

4. Highlight any discrepancies between the documented architecture (in CLAUDE.md files) and the actual code.
