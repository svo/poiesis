---
name: shared-schema
description: Manages shared data contracts and schemas between services — the definitions that multiple services must agree on. Use when viewing, modifying, or validating cross-service schemas, or when understanding how data flows between components.
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Shared Schema

Shared schemas are the most critical contracts in a multi-service architecture. They define how data is represented and are consumed by multiple services that must stay in sync.

## When to Use

- Adding a new field to a shared data structure
- Creating a new shared contract between services
- Understanding how data flows between components
- Auditing schema consistency across services

## Identifying Shared Schemas

Read the project's CLAUDE.md and each service's CLAUDE.md to identify:
- Data structures that appear in multiple services
- API request/response shapes that cross service boundaries
- Event payloads passed between services
- Configuration schemas shared across components

## Modification Protocol

Changes to shared schemas are high-impact. When modifying:

1. Identify all services that produce or consume the schema
2. Update the canonical schema definition
3. Update every producer to output the new shape
4. Update every consumer to accept the new shape
5. Add migration logic for existing stored data if applicable
6. Update tests in all affected services

## Before Modifying

Always use `/specify` to create a spec for schema changes first. Schema changes affect multiple services and should be planned carefully.

## Validation Checklist

- All references to the schema are consistent across services
- No service uses fields that don't exist in the schema
- Required fields are validated at system boundaries
- Default values are documented and consistent
- Breaking changes have a migration path
