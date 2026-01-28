# Initialize Library Standards

Initialize library-specific standards for Z3 Stack projects. This command:
1. Detects the framework (TanStack Start or Next.js) from package.json
2. Checks library versions against existing standards
3. Auto-refreshes outdated standards from official documentation (checking llms.txt first)
4. Saves refreshed standards back to the base install
5. Copies relevant standards to the project's agent-os folder

## Important Guidelines

- **Always use AskUserQuestion tool** when asking the user anything
- **Prefer llms.txt** — Always check for llms.txt files first as the source of truth
- **Save to base install** — Refreshed standards are saved to `~/agent-os/library-standards/` for reuse

## Process

### Step 1: Read package.json

Read the project's `package.json` to detect:
- Which framework is used (TanStack Start via `@tanstack/start` or `@tanstack/react-router`, OR Next.js via `next`)
- Current versions of all Z3 stack libraries

Look for these packages and their versions:
- `convex`
- `better-auth`
- `@tanstack/react-form`
- `@tanstack/react-query`
- `@tanstack/react-router` or `@tanstack/start` (TanStack variant)
- `next` (Next.js variant)
- `tailwindcss`
- `effect` (optional)

### Step 2: Check Version Compatibility

For each detected library, read the corresponding `~/agent-os/library-standards/[library]/version.yml` file.

Compare the **major version** from package.json against the `current_major` in version.yml.

If the project's major version is **greater than** the standards' major version, the standards are outdated.

### Step 3: Handle Outdated Standards

**Default behavior:**
- Notify the user which libraries have outdated standards
- Automatically refresh those standards from official documentation
- Save the refreshed standards back to `~/agent-os/library-standards/`

**With --confirm flag:**
- Show which libraries are outdated
- Use AskUserQuestion for confirmation before refreshing

**With --no-refresh flag:**
- Skip refresh, use existing standards even if outdated

### Step 4: Refresh Outdated Standards (if needed)

For each library that needs refreshing:

#### 4a. Check for llms.txt First

Many libraries provide an `llms.txt` file with LLM-optimized documentation. Check these URLs in order:

1. `https://[library-domain]/llms.txt`
2. `https://[library-domain]/llms-full.txt` (expanded version if available)
3. `https://[library-domain]/.well-known/llms.txt`

**Known llms.txt locations:**
- Convex: `https://docs.convex.dev/llms.txt`
- TanStack: `https://tanstack.com/llms.txt`
- Effect: `https://effect.website/llms.txt`
- Next.js: `https://nextjs.org/llms.txt`
- Tailwind: `https://tailwindcss.com/llms.txt`

If an llms.txt file is found:
- Parse it for best practices sections
- Extract links to crucial documentation pages
- Follow links to important guides mentioned in the llms.txt

#### 4b. Fallback to Web Search

If no llms.txt is available, use web search:

**Search patterns:**
- `[library] best practices v[version] site:[official-docs-domain]`
- `[library] [version] guide official documentation`
- `[library] llms.txt` (to discover if one exists)

#### 4c. Extract and Structure Content

From either llms.txt or web search results, extract:
- Best practices and recommended patterns
- Common pitfalls to avoid
- Links to crucial documentation sections
- Version-specific breaking changes or new features

Structure the content into the standard format with conditional-block tags for smart section loading.

#### 4d. Save to Base Install

Update these files in `~/agent-os/library-standards/[library]/`:
- `v[X].x/best-practices.md` — Updated standards content
- `version.yml` — New version numbers and current date

### Step 5: Install Standards to Project

#### 5a. Create Standards Directory Structure

Ensure these directories exist in the project:
```
agent-os/
└── standards/
    ├── global/
    ├── frontend/
    └── backend/
```

#### 5b. Copy Global Standards

Copy from the profile's standards (if using create-z3-app profile):
- `best-practices.md`
- `coding-style.md`
- `performance.md`

#### 5c. Copy Library Standards

Based on detected framework, copy appropriate library standards:

**Always copy (core libraries):**
- `convex/v[X].x/best-practices.md` → `standards/backend/convex.md`
- `better-auth/v[X].x/best-practices.md` → `standards/backend/better-auth.md`
- `shadcn-ui/v[X].x/best-practices.md` → `standards/frontend/shadcn-ui.md`
- `tailwind/v[X].x/best-practices.md` → `standards/frontend/tailwind.md`
- `tanstack-form/v[X].x/best-practices.md` → `standards/frontend/tanstack-form.md`
- `tanstack-query/v[X].x/best-practices.md` → `standards/frontend/tanstack-query.md`

**TanStack variant (if @tanstack/start or @tanstack/react-router detected):**
- `tanstack-router/v[X].x/best-practices.md` → `standards/frontend/tanstack-router.md`
- `tanstack-start/v[X].x/best-practices.md` → `standards/frontend/tanstack-start.md`

**Next.js variant (if next detected):**
- `nextjs/v[X].x/best-practices.md` → `standards/frontend/nextjs.md`

**Optional (if --with-effect flag or effect detected in package.json):**
- `effect/v[X].x/best-practices.md` → `standards/backend/effect.md`

### Step 6: Update Index

After copying standards, update `agent-os/standards/index.yml` with entries for all installed standards.

### Step 7: Report Results

After completion, output:

```
Library standards initialized!

Framework detected: [TanStack Start | Next.js]

✓ Global standards installed
✓ Backend standards: convex, better-auth[, effect]
✓ Frontend standards: shadcn-ui, tailwind, tanstack-form, tanstack-query, [tanstack-router, tanstack-start | nextjs]

[If any were refreshed:]
🔄 Refreshed outdated standards:
   - [library] (v[old] → v[new])

Standards saved to: agent-os/standards/
Base install updated: ~/agent-os/library-standards/
```

## Command Flags

- `--confirm` - Require confirmation before refreshing outdated standards
- `--no-refresh` - Skip refresh, use existing standards even if outdated
- `--refresh [library]` - Force refresh a specific library (even if not outdated)
- `--with-effect` - Include Effect library standards

## Library Standards Structure

The base install contains versioned library standards:

```
~/agent-os/library-standards/
├── convex/
│   ├── version.yml
│   └── v1.x/
│       └── best-practices.md
├── better-auth/
│   ├── version.yml
│   └── v1.x/
│       └── best-practices.md
└── ...
```

Each `version.yml` contains:
```yaml
library_name: convex
current_major: 1
current_version: 1.17.4
last_updated: 2026-01-25
llms_txt_url: https://docs.convex.dev/llms.txt
docs_url: https://docs.convex.dev
```

## Related Commands

- `/plan-product` - Set up product documentation
- `/discover-standards` - Extract patterns from your codebase
- `/inject-standards` - Load standards into context
