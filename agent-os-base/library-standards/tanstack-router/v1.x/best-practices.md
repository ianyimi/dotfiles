# TanStack Router Best Practices

## Context

Standards for routing with TanStack Router. Apply these patterns for route configuration, code splitting, and data loading.

<conditional-block context-check="route-organization">
IF this Route Organization section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following route organization patterns

## Route Organization

### File-Based vs Code-Based Routing

Choose based on project needs:

**File-Based Routing**: Uses file system conventions
```
src/routes/
├── __root.tsx
├── index.tsx
├── about.tsx
├── posts/
│   ├── index.tsx
│   └── $postId.tsx
└── _authenticated/
    ├── dashboard.tsx
    └── settings.tsx
```

**Code-Based Routing**: Explicit route tree
```typescript
const routeTree = rootRoute.addChildren([
  indexRoute,
  aboutRoute,
  postsRoute.addChildren([postRoute]),
  authenticatedRoute.addChildren([dashboardRoute, settingsRoute]),
]);
```

### Route Naming Conventions

- `__root.tsx` - Root layout route
- `index.tsx` - Index route for path
- `$paramName.tsx` - Dynamic segment
- `_layout.tsx` - Layout route (doesn't add path segment)
- `_authenticated/` - Route group prefix

</conditional-block>

<conditional-block context-check="code-splitting">
IF this Code Splitting section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following code splitting patterns

## Code Splitting

### Lazy Route Components

Split code at route boundaries:

```typescript
// routes/posts/$postId.tsx
import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/posts/$postId")({
  component: () => import("./PostPage").then((m) => m.PostPage),
});
```

### Automatic Code Splitting

Enable tooling for automatic splitting:

```typescript
// vite.config.ts
import { TanStackRouterVite } from "@tanstack/router-vite-plugin";

export default defineConfig({
  plugins: [TanStackRouterVite()],
});
```

### Manual Code Splitting

For fine-grained control:

```typescript
const PostPage = lazy(() => import("./PostPage"));

const postRoute = createRoute({
  getParentRoute: () => postsRoute,
  path: "$postId",
  component: PostPage,
});
```

</conditional-block>

<conditional-block context-check="data-loading">
IF this Data Loading section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following data loading patterns

## Data Loading Strategies

### Standard Data Loading

Load data before rendering:

```typescript
export const Route = createFileRoute("/posts/$postId")({
  loader: async ({ params }) => {
    const post = await fetchPost(params.postId);
    return { post };
  },
  component: PostPage,
});

function PostPage() {
  const { post } = Route.useLoaderData();
  return <article>{post.title}</article>;
}
```

### Deferred Data Loading

Progressive data fetching for faster initial render:

```typescript
export const Route = createFileRoute("/posts/$postId")({
  loader: async ({ params }) => {
    const post = await fetchPost(params.postId);
    // Defer comments loading
    const commentsPromise = fetchComments(params.postId);
    return { post, commentsPromise };
  },
});

function PostPage() {
  const { post, commentsPromise } = Route.useLoaderData();
  return (
    <article>
      {post.title}
      <Suspense fallback={<CommentsSkeleton />}>
        <Await promise={commentsPromise}>
          {(comments) => <Comments data={comments} />}
        </Await>
      </Suspense>
    </article>
  );
}
```

### External Data Loading with TanStack Query

Integrate with external state management:

```typescript
export const Route = createFileRoute("/posts/$postId")({
  loader: ({ params, context }) => {
    return context.queryClient.ensureQueryData({
      queryKey: ["posts", params.postId],
      queryFn: () => fetchPost(params.postId),
    });
  },
});
```

</conditional-block>

## Search Parameters

### Type-Safe Search Params

```typescript
import { z } from "zod";

const postSearchSchema = z.object({
  page: z.number().default(1),
  sort: z.enum(["newest", "oldest"]).default("newest"),
});

export const Route = createFileRoute("/posts")({
  validateSearch: postSearchSchema,
});

function PostsPage() {
  const { page, sort } = Route.useSearch();
  // page and sort are typed
}
```

### Navigate with Search Params

```typescript
const navigate = useNavigate();

navigate({
  to: "/posts",
  search: { page: 2, sort: "oldest" },
});
```

## Authentication Patterns

### Protected Routes

```typescript
const authenticatedRoute = createRoute({
  id: "_authenticated",
  getParentRoute: () => rootRoute,
  beforeLoad: async ({ context }) => {
    if (!context.auth.isAuthenticated) {
      throw redirect({ to: "/login" });
    }
  },
});
```

### Route Context

```typescript
const rootRoute = createRootRouteWithContext<{
  auth: AuthState;
  queryClient: QueryClient;
}>()({
  component: RootComponent,
});
```

## Related Standards

- See [tanstack-query/best-practices.md](../tanstack-query/best-practices.md) for data fetching
- See [performance.md](../../global/performance.md) for loading optimization
