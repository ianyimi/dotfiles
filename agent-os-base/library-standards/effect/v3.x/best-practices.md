# Effect Best Practices

## Context

Standards for functional programming with Effect. Apply these patterns for error handling, composition, and dependency injection.

<conditional-block context-check="generators">
IF this Generator Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following generator patterns

## Using Generators with Effect.gen

### Core Pattern

Use `Effect.gen` with generator functions to write effectful code that resembles synchronous code:

```typescript
import { Effect } from "effect";

const program = Effect.gen(function* () {
  const result1 = yield* someEffect;
  const result2 = yield* anotherEffect;
  return combine(result1, result2);
});
```

### Requirements

- TypeScript's `downlevelIteration` flag or `target` of `"es2015"` or higher
- Use `yield*` (not `yield`) to handle effects

### Control Flow Integration

Standard constructs work directly within generators:

```typescript
const program = Effect.gen(function* () {
  let i = 1;
  while (i < 10) {
    if (i % 2 === 0) {
      yield* Effect.log(`Even: ${i}`);
    }
    i++;
  }
});
```

</conditional-block>

<conditional-block context-check="error-handling">
IF this Error Handling section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following error handling patterns

## Error Handling

### Fail-Fast Behavior

The generator stops at the first error encountered:

```typescript
const program = Effect.gen(function* () {
  yield* task1; // executes
  yield* task2; // executes
  yield* Effect.fail("error"); // execution halts here
  yield* task3; // never runs
});
```

### Typed Errors with Schema.TaggedError

```typescript
import { Schema } from "@effect/schema";

class UserNotFoundError extends Schema.TaggedError<UserNotFoundError>()(
  "UserNotFoundError",
  {
    userId: Schema.String,
  }
) {}

class ValidationError extends Schema.TaggedError<ValidationError>()(
  "ValidationError",
  {
    field: Schema.String,
    message: Schema.String,
  }
) {}
```

### Type Narrowing

Always include explicit returns after failures for TypeScript inference:

```typescript
const program = Effect.gen(function* () {
  const user = yield* findUser(userId);

  if (user === undefined) {
    return yield* Effect.fail(new UserNotFoundError({ userId }));
  }

  // TypeScript knows user is defined
  return `Hello, ${user.name}`;
});
```

### Error Introduction

Inject errors explicitly within the flow:

```typescript
const program = Effect.gen(function* () {
  yield* task1;
  yield* task2;
  yield* Effect.fail(new SomeError({ reason: "Something went wrong" }));
});
```

</conditional-block>

<conditional-block context-check="services">
IF this Services section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following service patterns

## Services and Dependency Injection

### Define Services with Context.Tag

```typescript
import { Context, Effect, Layer } from "effect";

// Service interface
interface UserRepository {
  readonly findById: (id: string) => Effect.Effect<User | undefined>;
  readonly save: (user: User) => Effect.Effect<void>;
}

// Service tag
const UserRepository = Context.Tag<UserRepository>();
```

### Create Service Implementations

```typescript
const UserRepositoryLive = Layer.succeed(UserRepository, {
  findById: (id) =>
    Effect.gen(function* () {
      // Implementation
      return yield* db.users.findUnique({ where: { id } });
    }),
  save: (user) =>
    Effect.gen(function* () {
      yield* db.users.upsert({ where: { id: user.id }, create: user, update: user });
    }),
});
```

### Use Services in Effects

```typescript
const getUser = (userId: string) =>
  Effect.gen(function* () {
    const repo = yield* UserRepository;
    const user = yield* repo.findById(userId);

    if (!user) {
      return yield* Effect.fail(new UserNotFoundError({ userId }));
    }

    return user;
  });
```

### Provide Layers

```typescript
const program = getUser("123").pipe(Effect.provide(UserRepositoryLive));
```

</conditional-block>

<conditional-block context-check="composition">
IF this Composition section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following composition patterns

## Composition Patterns

### Chain Multiple Async Operations

```typescript
const program = Effect.gen(function* () {
  const amount = yield* fetchTransactionAmount;
  const rate = yield* fetchDiscountRate;
  const discounted = yield* applyDiscount(amount, rate);
  return addServiceCharge(discounted);
});
```

### Parallel Execution

```typescript
const program = Effect.gen(function* () {
  const [user, posts, notifications] = yield* Effect.all([
    getUser(userId),
    getPosts(userId),
    getNotifications(userId),
  ]);

  return { user, posts, notifications };
});
```

### Passing Context (`this`)

Use the two-argument overload to reference object context:

```typescript
class MyService {
  private readonly multiplier = 2;

  compute = Effect.gen(this, function* () {
    const value = yield* getValue();
    return value * this.multiplier;
  });
}
```

</conditional-block>

## Retry Policies

### Exponential Backoff with Jitter

```typescript
import { Schedule } from "effect";

const retryPolicy = Schedule.exponential("100 millis").pipe(
  Schedule.jittered,
  Schedule.compose(Schedule.recurs(3))
);

const programWithRetry = program.pipe(Effect.retry(retryPolicy));
```

## Observability

### Tracing with Spans

```typescript
const tracedProgram = Effect.gen(function* () {
  yield* Effect.log("Starting operation");
  const result = yield* someOperation;
  yield* Effect.log("Operation complete");
  return result;
}).pipe(Effect.withSpan("myOperation"));
```

## Related Standards

- See [error-handling.md](../../global/error-handling.md) for error patterns
- See [convex/best-practices.md](../convex/best-practices.md) for Effect in Convex actions
