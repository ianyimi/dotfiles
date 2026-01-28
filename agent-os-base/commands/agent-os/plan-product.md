# Plan Product

Establish foundational product documentation through an interactive conversation. Creates mission, roadmap, and tech stack files in `agent-os/product/`.

## Important Guidelines

- **Always use AskUserQuestion tool** when asking the user anything
- **Keep it lightweight** — gather enough to create useful docs without over-documenting
- **Ask everything at once** — combine all questions into ONE AskUserQuestion call for efficiency

## Process

### Step 1: Check for Existing Product Docs

Check if `agent-os/product/` exists and contains any of these files:
- `mission.md`
- `roadmap.md`
- `tech-stack.md`

**If any files exist**, use AskUserQuestion:

```
I found existing product documentation:
- mission.md: [exists/missing]
- roadmap.md: [exists/missing]
- tech-stack.md: [exists/missing]

Would you like to:
1. Start fresh (replace all)
2. Update specific files
3. Cancel

(Choose 1, 2, or 3)
```

If option 2, ask which files to update and only gather info for those.
If option 3, stop here.

**If no files exist**, proceed to Step 1.5.

### Step 1.5: Discover Important Project Libraries

Automatically discover project dependencies and fetch documentation for the most important ones.

#### 1.5a: Silently Detect & Analyze (No Output Yet)

**Step 1: Identify package manager and dependencies**

Check for these files in order:
- `package.json` (Node.js/JavaScript)
- `Gemfile` (Ruby)
- `requirements.txt` or `pyproject.toml` (Python)
- `go.mod` (Go)
- `Cargo.toml` (Rust)
- `composer.json` (PHP)

Read all production dependencies (skip dev dependencies for brevity).

**Step 2: Scan codebase for usage frequency**

For each dependency, count mentions in code files:
- Import/require statements
- Direct package references
- Configuration files

Sort dependencies by usage count (highest to lowest).

**Step 3: Generate library descriptions**

For each library, generate a brief description (1 sentence) based on:
- Common knowledge (e.g., "react" = "UI library for building interfaces")
- Quick pattern matching on library name
- Package description if available in package manager file

Keep descriptions generic and neutral. Examples:
- `react`: "UI library for building user interfaces"
- `zod`: "TypeScript-first schema validation"
- `convex`: "Backend database and API platform"
- `tailwindcss`: "Utility-first CSS framework"

#### 1.5b: Ask Everything in ONE AskUserQuestion Call

Use AskUserQuestion with multiSelect to present ALL libraries at once:

**Question text:**
```
I found [N] dependencies in your project, sorted by usage frequency:

**Heavy Usage (100+ references):**
• react (872 refs) — UI library for building user interfaces
• typescript (654 refs) — Static type checking for JavaScript
• next (445 refs) — React framework for production applications

**Moderate Usage (20-100 references):**
• convex (87 refs) — Backend database and API platform
• better-auth (45 refs) — Authentication library
• tailwindcss (34 refs) — Utility-first CSS framework
• zod (28 refs) — TypeScript-first schema validation

**Light Usage (<20 references):**
• dotenv (5 refs) — Environment variable loader
• eslint (3 refs) — JavaScript linter
...

Which libraries are most important for working on this project?

If any descriptions are wrong, type "fix: [library] - [correct description]" in the Other option.
Otherwise, select the libraries to fetch documentation for (recommended: top 5-10).
```

**Options:**
- multiSelect: true
- Create one option per library in format:
  - label: `library-name (count refs)`
  - description: `[auto-generated description]`
- Include top 20 libraries max to avoid overwhelming the UI

**After receiving response:**
- If user typed corrections in "Other", update descriptions and ask again
- Otherwise, proceed with selected libraries

#### 1.5c: Fetch Documentation for Selected Libraries

For each selected library:

**1. Determine official docs domain:**

Use WebSearch to find official documentation:
```
[library name] official documentation
```

Extract primary docs domain (e.g., `docs.convex.dev`, `react.dev`).

**2. Check for llms.txt (Priority #1):**

Try these URLs in order using WebFetch:
1. `https://[docs-domain]/llms.txt`
2. `https://[docs-domain]/llms-full.txt`
3. `https://[docs-domain]/.well-known/llms.txt`
4. `https://[main-site]/llms.txt`

If found:
- Parse llms.txt content
- Extract links to best practices sections
- Note llms.txt URL for saving

**3. Fallback to web search if no llms.txt:**

Search for:
```
[library] best practices [version] site:[docs-domain]
[library] core concepts site:[docs-domain]
```

Use WebFetch on top 2-3 result URLs.

**4. Extract key information:**

From gathered docs, extract:
- Best practices and recommended patterns
- Common pitfalls to avoid
- Core concepts and mental models
- Version-specific notes

Focus on information that helps AI write better code.

#### 1.5d: Save Library Standards to Base Install

For each library, save to `~/agent-os/library-standards/[library-name]/`:

**version.yml:**
```yaml
library: [library-name]
current_major: [major-version]
current_minor: [minor-version]
last_updated: [today's date YYYY-MM-DD]
docs_source: [official docs URL]
llms_txt_url: [llms.txt URL if found, or null]
best_practices_source: [best practices page URL]
```

**v[X].x/best-practices.md:**

Use this format with conditional blocks for smart loading:

```markdown
# [Library Name] Best Practices

## Context

Standards for [Library]. Apply these patterns for [use cases].

<conditional-block context-check="core-concepts">
IF this Core Concepts section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following concepts

## Core Concepts

### [Concept 1]

[Concise explanation]

- [Key point]
- [Key point]

\`\`\`[language]
// Example
\`\`\`

</conditional-block>

<conditional-block context-check="best-practices">
IF this Best Practices section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following practices

## Best Practices

### [Practice 1]

...

</conditional-block>

<conditional-block context-check="common-pitfalls">
IF this Common Pitfalls section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following pitfalls

## Common Pitfalls

### [Pitfall 1]

...

</conditional-block>
```

**Writing rules:**
- Concise — every word costs tokens
- Lead with rules, explain why second
- Code examples over prose
- Skip obvious/basic setup

#### 1.5e: Report Library Discovery Results

After processing all selected libraries:

```
✓ Library documentation fetched and saved!

Standards created for [N] libraries:
  - [lib1] (via llms.txt) → ~/agent-os/library-standards/[lib1]/
  - [lib2] (via web search) → ~/agent-os/library-standards/[lib2]/
  ...

📚 These standards are now available for use across all projects.

Continuing with product planning...
```

Then proceed to Step 2.

### Step 2: Gather All Product Information in ONE AskUserQuestion Call

Check if `agent-os/standards/global/tech-stack.md` exists first to determine tech stack question format.

Then use AskUserQuestion with ALL questions in a single call:

```json
{
  "questions": [
    {
      "question": "What problem does this product solve?",
      "header": "Problem",
      "options": [
        {"label": "N/A", "description": "Type your answer in Other"}
      ],
      "multiSelect": false
    },
    {
      "question": "Who is this product for?",
      "header": "Target Users",
      "options": [
        {"label": "N/A", "description": "Type your answer in Other"}
      ],
      "multiSelect": false
    },
    {
      "question": "What makes your solution unique?",
      "header": "Unique Value",
      "options": [
        {"label": "N/A", "description": "Type your answer in Other"}
      ],
      "multiSelect": false
    },
    {
      "question": "What are the must-have features for launch (MVP)?",
      "header": "MVP Features",
      "options": [
        {"label": "N/A", "description": "Type your answer in Other"}
      ],
      "multiSelect": false
    },
    {
      "question": "What features are planned for after launch? (or say 'none yet')",
      "header": "Future Features",
      "options": [
        {"label": "N/A", "description": "Type your answer in Other"}
      ],
      "multiSelect": false
    },
    {
      "question": "[Tech stack question - see below]",
      "header": "Tech Stack",
      "options": "[See tech stack options below]",
      "multiSelect": false
    }
  ]
}
```

**Tech Stack Question (Question 6):**

**If `agent-os/standards/global/tech-stack.md` exists:**
```
"question": "I found a tech stack standard in your standards: [summarize key tech]. Does this project use the same stack?"
"options": [
  {"label": "Same as standard", "description": "[Key technologies from standard]"},
  {"label": "Different", "description": "I'll specify in Other what this project uses"}
]
```

**If no tech-stack standard exists:**
```
"question": "What type of project is this and what technologies does it use?"
"options": [
  {"label": "Web App", "description": "Frontend + Backend (specify tech in Other)"},
  {"label": "CLI Tool", "description": "Command-line application (specify language in Other)"},
  {"label": "Library", "description": "Reusable package (specify language in Other)"},
  {"label": "Dotfiles/System", "description": "Configuration management (specify tools in Other)"}
]
```

**IMPORTANT:** This is ONE AskUserQuestion call with 6 questions. The user answers all at once.

### Step 3: Generate Files

Create the `agent-os/product/` directory if it doesn't exist.

Generate each file based on the information gathered:

#### mission.md

```markdown
# Product Mission

## Problem

[Insert what problem this product solves - from Step 2]

## Target Users

[Insert who this product is for - from Step 2]

## Solution

[Insert what makes the solution unique - from Step 2]
```

#### roadmap.md

```markdown
# Product Roadmap

## Phase 1: MVP

[Insert must-have features for launch - from Step 3]

## Phase 2: Post-Launch

[Insert planned future features - from Step 3, or "To be determined" if they said none yet]
```

#### tech-stack.md

```markdown
# Tech Stack

[Organize the tech stack information into logical sections]

## Frontend

[Frontend technologies, or "N/A" if not applicable]

## Backend

[Backend technologies, or "N/A" if not applicable]

## Database

[Database choice, or "N/A" if not applicable]

## Other

[Other tools, hosting, services - or omit this section if nothing mentioned]
```

### Step 4: Confirm Completion

After creating all files, output to user:

```
✓ Product documentation created:

  agent-os/product/mission.md
  agent-os/product/roadmap.md
  agent-os/product/tech-stack.md

Review these files to ensure they accurately capture your product vision.
You can edit them directly or run /plan-product again to update.
```

## Tips

- If the user provides very brief answers, that's fine — the docs can be expanded later
- If they want to skip a section, create the file with a placeholder like "To be defined"
- The `/shape-spec` command will read these files when planning features, so having them populated helps with context
