# TanStack Start Best Practices

## Context

Standards for full-stack applications with TanStack Start. Apply these patterns for server functions, SSR, and data loading.

<conditional-block context-check="server-functions">
IF this Server Functions section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following server function patterns

## Server Functions

### Define Server Functions

Create type-safe server-side functions:

```typescript
import { createServerFn } from "@tanstack/start";

const getUser = createServerFn("GET", async (userId: string) => {
  const user = await db.users.findUnique({ where: { id: userId } });
  if (!user) {
    throw new Error("User not found");
  }
  return user;
});
```

### Call Server Functions

```typescript
// In a component or loader
const user = await getUser(userId);

// Or with useServerFn hook
const { data, isLoading } = useServerFn(getUser, userId);
```

### Server Function with Mutations

```typescript
const createPost = createServerFn("POST", async (data: CreatePostInput) => {
  const post = await db.posts.create({ data });
  return post;
});
```

</conditional-block>

<conditional-block context-check="data-loading">
IF this Data Loading section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following data loading patterns

## Data Loading

### Route Loaders with Server Functions

```typescript
import { createFileRoute } from "@tanstack/react-router";

const getPost = createServerFn("GET", async (postId: string) => {
  return db.posts.findUnique({ where: { id: postId } });
});

export const Route = createFileRoute("/posts/$postId")({
  loader: async ({ params }) => {
    const post = await getPost(params.postId);
    return { post };
  },
  component: PostPage,
});
```

### Parallel Data Loading

Fetch multiple resources in parallel:

```typescript
export const Route = createFileRoute("/dashboard")({
  loader: async () => {
    const [user, stats, notifications] = await Promise.all([
      getUser(),
      getStats(),
      getNotifications(),
    ]);
    return { user, stats, notifications };
  },
});
```

### Streaming Data

Use deferred loading for non-critical data:

```typescript
export const Route = createFileRoute("/posts/$postId")({
  loader: async ({ params }) => {
    const post = await getPost(params.postId);
    // Stream comments after initial render
    const commentsPromise = getComments(params.postId);
    return { post, commentsPromise };
  },
});
```

</conditional-block>

<conditional-block context-check="ssr-patterns">
IF this SSR Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following SSR patterns

## SSR Patterns

### Hydration

TanStack Start handles hydration automatically. Ensure:
- Server and client render identical markup initially
- Avoid browser-only APIs in initial render

```typescript
function ClientOnlyComponent() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  return <BrowserOnlyFeature />;
}
```

### Meta Tags and SEO

```typescript
export const Route = createFileRoute("/posts/$postId")({
  loader: async ({ params }) => {
    const post = await getPost(params.postId);
    return { post };
  },
  head: ({ loaderData }) => ({
    title: loaderData.post.title,
    meta: [
      { name: "description", content: loaderData.post.excerpt },
      { property: "og:title", content: loaderData.post.title },
    ],
  }),
});
```

</conditional-block>

## Authentication

### Protected Server Functions

```typescript
const getPrivateData = createServerFn("GET", async () => {
  const session = await getSession();
  if (!session) {
    throw redirect({ to: "/login" });
  }
  return db.privateData.findMany({
    where: { userId: session.userId },
  });
});
```

### Session Management

```typescript
import { getCookie, setCookie } from "vinxi/http";

const getSession = createServerFn("GET", async () => {
  const sessionId = getCookie("session");
  if (!sessionId) return null;
  return db.sessions.findUnique({ where: { id: sessionId } });
});
```

## Error Handling

### Server Function Errors

```typescript
const updateUser = createServerFn("POST", async (data: UpdateUserInput) => {
  try {
    return await db.users.update({
      where: { id: data.id },
      data,
    });
  } catch (error) {
    if (error.code === "P2025") {
      throw new Error("User not found");
    }
    throw error;
  }
});
```

### Route Error Boundaries

```typescript
export const Route = createFileRoute("/posts/$postId")({
  errorComponent: ({ error }) => (
    <div className="p-4 bg-red-100">
      <h2>Error loading post</h2>
      <p>{error.message}</p>
    </div>
  ),
});
```

## Related Standards

- See [tanstack-router/best-practices.md](../tanstack-router/best-practices.md) for routing patterns
- See [tanstack-query/best-practices.md](../tanstack-query/best-practices.md) for caching
- See [convex/best-practices.md](../convex/best-practices.md) for backend integration
