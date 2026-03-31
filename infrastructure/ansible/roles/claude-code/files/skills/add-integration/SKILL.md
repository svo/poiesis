---
name: add-integration
description: Adds a new external integration or adapter to a project. Scaffolds the integration definition (triggers, actions, config schema) and the adapter implementation. Use when adding support for a new external service like Slack, GitHub, AWS, SMTP, etc.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash(*), Glob, Grep
---

# Add Integration

Scaffold a new external integration across the project's catalog and runtime services.

## Usage

`/add-integration <integration-name>`

Where `<integration-name>` is kebab-case (e.g. `slack`, `github-issues`, `smtp-email`).

## Process

1. **Read the project's CLAUDE.md** to understand the architecture and identify which services handle integration definitions and runtime execution.

2. **Create the definition** in the catalog/registry service:
   - Integration name and description
   - Available triggers (events that can start a workflow or process)
   - Available actions (operations the integration can perform)
   - Config schema (what fields the user must provide)
   - Authentication type (API key, OAuth2, basic auth, etc.)

3. **Create the runtime adapter** in the execution/runtime service:
   - Implement the adapter following the existing adapter pattern
   - Each trigger and action from the definition needs a corresponding implementation
   - Include input/output mapping for data flowing through the system

4. **Add credential type** if needed — update the credential handling to support the new authentication type.

5. **Test the integration:**
   - Unit tests for the definition validation
   - Unit tests for each trigger and action in the adapter
   - Verify the integration appears in the catalog/registry

6. **Commit** changes to each affected service separately.

## Integration Structure Pattern

```
# In the catalog/registry service
integrations/
  <name>/
    definition.json    # Triggers, actions, config schema

# In the runtime/execution service
adapters/
  <name>/
    __init__.py
    triggers.py        # Trigger implementations
    actions.py         # Action implementations
    auth.py            # Authentication handling
    tests/
      test_triggers.py
      test_actions.py
```

Adapt this structure to match the project's conventions — not every project will have separate catalog and runtime services. The key is that the definition (what the integration can do) and the implementation (how it does it) are clearly separated.
