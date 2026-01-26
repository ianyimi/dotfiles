# Convex Best Practices

## Context

Standards for building applications with Convex backend. Apply these patterns to queries, mutations, actions, and schema design.

<conditional-block context-check="query-patterns">
IF this Query Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following query patterns

## Query Patterns

### Await All Promises

Ensure every promise in async functions receives `await`. Missing awaits on operations like `ctx.scheduler.runAfter` or `ctx.db.patch` causes unexpected behavior or missed error handling.

**Implement the `no-floating-promises` ESLint rule.**

### Avoid `.filter()` on Database Queries

Filtering through code rather than `.filter()` syntax offers equivalent performance. Prefer conditions in `.withIndex()` or `.withSearchIndex()` over `.filter()`.

```typescript
// Preferred: Use index conditions
const users = await ctx.db
  .query("users")
  .withIndex("by_status", (q) => q.eq("status", "active"))
  .collect();

// Avoid: Filter in application code
const users = await ctx.db
  .query("users")
  .filter((q) => q.eq(q.field("status"), "active"))
  .collect();
```

### Use Indexes Strategically

- Redundant indexes waste storage and write overhead
- Query patterns like `by_foo` and `by_foo_and_bar` typically need just `by_foo_and_bar`
- Exception: Separate indexes needed if sorting by `_creationTime` for specific queries

### Limit `.collect()` Usage

Only call `.collect()` on results under ~1000 documents. Larger result sets should use:
- Pagination
- Indexes with limits
- Denormalized counts

All results returned from `.collect` count towards database bandwidth.

### Avoid `Date.now()` in Queries

Queries don't re-run when time changes, causing potentially stale results. Instead:
- Use scheduled functions updating a boolean field like `isReleased: true`
- Pass time as an explicit argument from the client rounded to the nearest minute

</conditional-block>

<conditional-block context-check="mutation-patterns">
IF this Mutation Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following mutation and action patterns

## Mutation & Action Patterns

### Implement Argument Validators

All public functions require validators via `args`. This prevents any Convex value being passed, protecting against client spoofing and unexpected data structures.

```typescript
export const createUser = mutation({
  args: {
    name: v.string(),
    email: v.string(),
  },
  handler: async (ctx, args) => {
    // args are now typed and validated
  },
});
```

### Enforce Access Control

- Check `ctx.auth.getUserIdentity()` for authenticated functions
- Use unguessable identifiers (UUIDs, Convex IDs) for checks—never email or username
- Favor granular functions like `setTeamOwner` over generic `updateTeam`

```typescript
export const updateUserProfile = mutation({
  args: { name: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Unauthenticated");
    }
    // Use identity.subject (unique ID), not email
  },
});
```

### Schedule Only Internal Functions

Both `ctx.scheduler` and `ctx.run*` calls should target `internal` functions, not `api` functions, preventing potentially malicious attackers from triggering sensitive operations directly.

```typescript
// Correct: Schedule internal function
await ctx.scheduler.runAfter(0, internal.tasks.processEmail, { userId });

// Avoid: Scheduling public API function
await ctx.scheduler.runAfter(0, api.tasks.processEmail, { userId });
```

### Minimize Sequential Calls

Multiple sequential `ctx.runQuery()` or `ctx.runMutation()` calls in actions lose transaction guarantees. Combine them into a single function call when possible.

Exception: Intentional multi-transaction processing (migrations, bulk operations).

### Avoid Unnecessary `runAction`

`runAction` carries overhead equivalent to a separate function with its own resources. Use plain TypeScript functions instead. Only use `runAction` when calling Node.js-dependent code from the Convex runtime.

</conditional-block>

<conditional-block context-check="code-organization">
IF this Code Organization section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following organization patterns

## Code Organization

### Centralize Business Logic

Structure code with a `convex/model` directory containing helper functions. Public APIs (`query`, `mutation`, `action`) should be thin wrappers.

```
convex/
├── model/
│   ├── users.ts      # User business logic
│   ├── teams.ts      # Team business logic
│   └── permissions.ts # Permission helpers
├── users.ts          # User API (thin wrappers)
└── teams.ts          # Team API (thin wrappers)
```

### Include Table Names Explicitly

Since version 1.31.0, `ctx.db.get()`, `patch()`, `replace()`, and `delete()` require the table name as the first argument.

```typescript
// Current pattern (v1.31.0+)
const user = await ctx.db.get("users", userId);
await ctx.db.patch("users", userId, { name: "Updated" });
```

</conditional-block>

## Performance & Safety

### Validation & Type Safety

Use argument and return value validators. For HTTP actions, employ validation libraries like Zod to ensure request shape compliance.

### Row-Level Security Options

Implement either:
- Per-function access checks
- Row-Level Security (RLS) patterns automatically checking document access on load

### Query Caching

Passing explicit, slowly-changing arguments (e.g., time rounded to minutes) optimizes Convex query cache reuse and prevents unnecessary re-execution.

## Related Standards

- See [error-handling.md](../../global/error-handling.md) for error patterns
- See [validation.md](../../global/validation.md) for validation approaches
