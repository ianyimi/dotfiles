---
description: Investigate a library, API, or technical concept and produce a concise findings doc saved to .pi/agent-docs/research/. Checks for prior research first. Agent reads actual source, docs, or changelog — does not summarize from training data alone.
---

# Research

Investigate a library, API, concept, or technical decision and produce a durable findings doc.

---

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

## Process

### Step 1 — Check for prior research

Before starting, scan `.pi/agent-docs/research/` for existing files on the same topic. If one exists, read it and ask:

> I found prior research on `<topic>` from <date>. Update it or start fresh?

If the prior research already answers the question, present the findings and stop — don't re-investigate.

### Step 2 — Define the question

Ask:
> What specifically do you need to know? (e.g., "How does X handle Y?", "What's the difference between A and B?", "Is library Z safe to use for this?")

> What decision does this research feed? (Helps scope the output.)

### Step 3 — Read tech-stack context

Check `.pi/agent-docs/product/tech-stack.md` for:
- The version of the library being researched (from the manifest section)
- Any prior decisions about this library in the codebase

This prevents researching behavior from the wrong version.

### Step 4 — Identify sources

Based on the question, identify the best sources:
- Official docs
- Changelog / release notes (for version-specific questions)
- Source code (for behavior questions docs don't answer)
- GitHub issues (for known bugs or limitations)

Do not rely on training data alone for anything version-specific or behavior-specific.

### Step 5 — Investigate

Read the identified sources. Extract only what's relevant to the question — do not summarize entire docs.

### Step 6 — Produce findings

Write to `.pi/agent-docs/research/<topic>.md` (update if file exists, create if not):

```markdown
# Research: <topic>

**Question:** <the specific question>
**Decision it feeds:** <what this informs>
**Version researched:** <library version if applicable>
**Date:** <YYYY-MM-DD>

## Findings

<concise answer — what is actually true>

## Key Details

<bullet points of relevant specifics>

## Caveats / Limitations

<what the answer doesn't cover, version dependencies, known issues>

## Sources

- <source 1>
- <source 2>
```

### Step 7 — Summarize for developer

After writing the file:
> Research complete: <one-sentence answer to the question>
> Full findings at `.pi/agent-docs/research/<topic>.md`

---

## Rules

- No hedging ("it might", "probably") — if unsure, say what you checked and what was ambiguous
- No lengthy summaries of things the developer didn't ask about
- If the answer is "it depends", say what it depends on and give the answer for each case
- Save the file even for quick research — it's reusable context for future sessions
- If the research contradicts a prior decision in ideaLog or developer-preferences.md, flag it explicitly
