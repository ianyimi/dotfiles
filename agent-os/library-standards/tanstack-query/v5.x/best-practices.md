# TanStack Query Best Practices

## Context

Standards for data fetching and caching with TanStack Query. Apply these patterns for queries, mutations, caching, and performance optimization.

<conditional-block context-check="query-configuration">
IF this Query Configuration section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following query configuration patterns

## Query Configuration

### Stable Query Keys

Use stable, serializable query keys for cache identification:

```typescript
// Query key factory pattern
const userKeys = {
  all: ["users"] as const,
  lists: () => [...userKeys.all, "list"] as const,
  list: (filters: Filters) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, "detail"] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};

// Usage
const { data } = useQuery({
  queryKey: userKeys.detail(userId),
  queryFn: () => fetchUser(userId),
});
```

### Configure Stale Time Intentionally

Queries remain "fresh" until their stale time expires:

```typescript
const { data } = useQuery({
  queryKey: ["user", userId],
  queryFn: fetchUser,
  staleTime: 5 * 60 * 1000, // 5 minutes
});
```

### Set Garbage Collection Time

Control memory usage with `gcTime`:

```typescript
const { data } = useQuery({
  queryKey: ["user", userId],
  queryFn: fetchUser,
  gcTime: 10 * 60 * 1000, // 10 minutes after becoming unused
});
```

</conditional-block>

<conditional-block context-check="refetch-behavior">
IF this Refetch Behavior section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following refetch patterns

## Refetch Behaviors

### Default Refetch Triggers

- Window regains focus (configurable via `focusManager`)
- Network reconnects (via `onlineManager`)
- Background refetches when stale queries are accessed

### Configure Refetch Behavior

```typescript
const { data } = useQuery({
  queryKey: ["user", userId],
  queryFn: fetchUser,
  refetchOnWindowFocus: false,
  refetchOnReconnect: true,
  refetchInterval: 30000, // Poll every 30 seconds
});
```

</conditional-block>

<conditional-block context-check="mutation-patterns">
IF this Mutation Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following mutation patterns

## Mutation Management

### Invalidate Related Queries After Mutations

```typescript
const queryClient = useQueryClient();

const mutation = useMutation({
  mutationFn: updateUser,
  onSuccess: () => {
    // Invalidate and refetch
    queryClient.invalidateQueries({ queryKey: userKeys.all });
  },
});
```

### Optimistic Updates

```typescript
const mutation = useMutation({
  mutationFn: updateUser,
  onMutate: async (newUser) => {
    // Cancel outgoing refetches
    await queryClient.cancelQueries({ queryKey: userKeys.detail(newUser.id) });

    // Snapshot previous value
    const previousUser = queryClient.getQueryData(userKeys.detail(newUser.id));

    // Optimistically update
    queryClient.setQueryData(userKeys.detail(newUser.id), newUser);

    return { previousUser };
  },
  onError: (err, newUser, context) => {
    // Rollback on error
    queryClient.setQueryData(
      userKeys.detail(newUser.id),
      context?.previousUser
    );
  },
  onSettled: () => {
    // Always refetch after error or success
    queryClient.invalidateQueries({ queryKey: userKeys.all });
  },
});
```

### Use Mutation Responses to Update Cache

```typescript
const mutation = useMutation({
  mutationFn: updateUser,
  onSuccess: (data) => {
    // Use returned data to update cache directly
    queryClient.setQueryData(userKeys.detail(data.id), data);
  },
});
```

</conditional-block>

## Performance Optimization

### Parallel Queries

Execute multiple queries simultaneously:

```typescript
const results = useQueries({
  queries: [
    { queryKey: ["user", userId], queryFn: () => fetchUser(userId) },
    { queryKey: ["posts", userId], queryFn: () => fetchUserPosts(userId) },
  ],
});
```

### Dependent Queries

Execute sequentially when one depends on another:

```typescript
const { data: user } = useQuery({
  queryKey: ["user", userId],
  queryFn: () => fetchUser(userId),
});

const { data: posts } = useQuery({
  queryKey: ["posts", user?.id],
  queryFn: () => fetchUserPosts(user!.id),
  enabled: !!user, // Only run when user is available
});
```

### Prefetching

Anticipate user needs:

```typescript
const queryClient = useQueryClient();

// Prefetch on hover
const handleMouseEnter = () => {
  queryClient.prefetchQuery({
    queryKey: userKeys.detail(userId),
    queryFn: () => fetchUser(userId),
  });
};
```

### Selective Subscriptions

Prevent unnecessary re-renders:

```typescript
const { data } = useQuery({
  queryKey: ["user", userId],
  queryFn: fetchUser,
  select: (data) => data.name, // Only re-render when name changes
});
```

## Related Standards

- See [convex/best-practices.md](../convex/best-practices.md) for backend integration
- See [performance.md](../../global/performance.md) for async waterfall prevention
