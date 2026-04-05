---
name: sequential-thinking
description: Break down complex problems into explicit sequential reasoning steps with revision, branching, hypothesis generation, and verification
user_invocable: true
---

# Sequential Thinking

## Overview

A structured, reflective problem-solving process that breaks complex problems into numbered thought steps. Each thought can build on, question, or revise previous insights as understanding deepens.

**Core principle:** Think step by step. Revise freely. Verify before concluding.

## When to Use

- Breaking down complex problems into steps
- Planning and design with room for revision
- Analysis that might need course correction
- Problems where the full scope is not clear initially
- Problems that require a multi-step solution
- Tasks that need to maintain context over multiple steps
- Situations where irrelevant information needs to be filtered out
- Architecture decisions with trade-offs
- Debugging where multiple hypotheses exist

## The Process

### Step 1: Estimate Scope

Before your first thought, estimate how many thought steps you will need. This estimate can be adjusted up or down as you progress.

### Step 2: Execute Thought Steps

For each thought step, output using this format:

```
**[Thought N/Total]**
[Your current thinking step]
```

Each thought can include:
- Regular analytical steps
- Revisions of previous thoughts
- Questions about previous decisions
- Realizations about needing more analysis
- Changes in approach
- Hypothesis generation
- Hypothesis verification

### Step 3: Revise When Needed

When a previous thought was wrong or incomplete, use:

```
**[Revision: Thought N revises Thought M]**
[Why the previous thought was wrong and the corrected thinking]
```

Do not pretend earlier thoughts were correct. Explicitly mark corrections.

### Step 4: Branch When Needed

When exploring an alternative approach from an earlier point, use:

```
**[Branch from Thought N: branch-name]**
[Alternative reasoning path]
```

You can have multiple branches. Label them clearly so you can compare outcomes.

### Step 5: Generate and Verify Hypotheses

When you have enough reasoning to form a hypothesis:

```
**[Hypothesis]**
[Your proposed solution or conclusion]

**[Verification]**
[Check the hypothesis against your chain of thought steps]
[Does it hold up? Are there contradictions?]
```

If verification fails, return to thought steps. Do not force a broken hypothesis.

### Step 6: Conclude

Only when you are genuinely satisfied with your reasoning:

```
**[Answer]**
[Your final, verified conclusion]
```

## Rules

1. **Start with an initial estimate** of needed thoughts, but adjust freely
2. **Question and revise** previous thoughts whenever warranted
3. **Add more thoughts** if needed, even after reaching your initial estimate
4. **Express uncertainty** when present — do not pretend to know
5. **Mark revisions and branches** explicitly so reasoning is traceable
6. **Ignore irrelevant information** — filter noise at each step
7. **Generate a hypothesis** when you have enough evidence
8. **Verify the hypothesis** against your chain of thought before concluding
9. **Repeat** hypothesis-verification cycles until satisfied
10. **Only conclude** when you have a genuinely verified answer

## Anti-Patterns

| Anti-Pattern | Correction |
|---|---|
| Skipping to answer without steps | Always show your reasoning chain |
| Pretending early thoughts were right | Use revision markers explicitly |
| Never revising | If nothing needs revision, you may not be thinking critically enough |
| Forcing a conclusion when verification fails | Return to thought steps instead |
| Ignoring branches when multiple approaches exist | Explore alternatives explicitly |
| Vague thoughts like "this seems right" | Be specific: what exactly and why |
| Adjusting estimate down to rush to finish | Add thoughts if the problem warrants them |
