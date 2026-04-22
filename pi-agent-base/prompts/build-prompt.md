---
description: Create a new project-specific Pi prompt via interactive interview. Asks what the prompt should do, how it should be invoked, what context it needs, and what output it produces. Writes the .md file to .pi/prompts/<name>.md.
---

# Build Prompt

Create a new prompt for this project through a structured interview.

---

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

## Interview

### 1 — Name + invoke

Ask:
> What should this prompt be called? (This becomes the invoke command and filename, e.g., `add-endpoint` → invoked as `/add-endpoint`)

### 2 — Purpose

Ask:
> In one sentence: what does this prompt do?

### 3 — When to use it

Ask:
> When should a developer reach for this prompt? What situation triggers it?

### 4 — Context it needs

Ask:
> What information does the agent need before it can act? (e.g., a file path, a feature name, a ticket ID). List each input.

### 5 — What it produces

Ask:
> What does the prompt output or change? (e.g., creates files, updates a config, writes a spec, runs a command)

### 6 — Step-by-step

Ask:
> Walk me through the steps this prompt should follow, in order. Be as specific as you want — I'll fill gaps.

### 7 — Edge cases

Ask:
> Are there any edge cases, things to avoid, or constraints this prompt must respect?

---

## Output

Generate `.pi/prompts/<name>.md`:

```markdown
---
description: <one-sentence purpose>
---

# <Name>

<When to use — one paragraph>

---

## Inputs

| Input | How to get it |
|-------|--------------|
| <input> | <ask user / read from file / detect> |

## Steps

<numbered steps from interview>

## Output

<what changes / what gets created>

## Edge Cases

<constraints and things to avoid>
```

Then announce:

> Prompt `<name>` created at `.pi/prompts/<name>.md`.
> Invoke it with: `/<name>`
