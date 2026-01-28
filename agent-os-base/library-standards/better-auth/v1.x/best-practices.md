# Better Auth Best Practices

## Context

Standards for implementing authentication with Better Auth. Apply these patterns for session management, security, and multi-device support.

<conditional-block context-check="session-management">
IF this Session Management section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following session patterns

## Session Management

### Configure Appropriate Expiration Windows

Set `expiresIn` and `updateAge` based on your security requirements. The default 7-day expiration with daily refresh provides a balance between user convenience and security.

- Shorter intervals increase security but may create friction
- Consider your application's sensitivity when configuring

### Implement Session Freshness Checks

Enable freshness validation for sensitive operations like password changes. The default 1-day `freshAge` works for most use cases.

```typescript
// Some endpoints require the session to be fresh
// meaning sessions must be recently created
const session = await auth.getSession({
  requireFresh: true,
});
```

### Strategic Session Refresh Disabling

Use `disableSessionRefresh: true` when you need absolute session duration limits without automatic extension.

</conditional-block>

<conditional-block context-check="caching-performance">
IF this Caching section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following caching patterns

## Caching & Performance

### Leverage Cookie Caching for Scalability

Enable cookie caching to reduce database queries on every session verification.

Choose your encoding strategy intentionally:
- **`compact`**: Best for internal-only sessions requiring maximum performance
- **`jwt`**: Use when external systems need token verification
- **`jwe`**: Select for sensitive data requiring encryption

### Balance Revocation Speed vs. Performance

Revoked sessions may remain active on other devices until the cookie cache expires. For security-critical applications, use shorter `maxAge` values (60-120 seconds) rather than disabling caching entirely.

</conditional-block>

<conditional-block context-check="stateless-sessions">
IF this Stateless Sessions section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following stateless patterns

## Stateless Sessions

### Implement Database-Less Architectures Carefully

Enable stateless mode through:
- `cookieCache` with `refreshCache` enabled
- `account.storeStateStrategy` set to `"cookie"`

This eliminates database dependency but sacrifices immediate revocation capabilities.

### Version Cookie Cache for Mass Invalidation

When requiring all sessions invalidated simultaneously, increment the `version` property and redeploy—this forces re-authentication without database queries.

</conditional-block>

## Security Patterns

### Revoke Sessions on Critical Changes

Use `revokeOtherSessions: true` when users change passwords to invalidate potentially compromised sessions on other devices.

```typescript
await auth.changePassword({
  currentPassword,
  newPassword,
  revokeOtherSessions: true,
});
```

### Validate Secondary Storage Integration

When using secondary storage (Redis, etc.), decide explicitly whether to preserve revoked sessions in the database via `preserveSessionInDatabase` for audit trails.

## Client-Side Session Handling

### Use Reactive Session Access

Prefer `useSession()` over repeated `getSession()` calls for real-time session state in UI components.

```typescript
// Preferred: Reactive hook
const { data: session, isPending } = useSession();

// Avoid: Repeated calls
const session = await getSession(); // Called multiple times
```

### Force Database Validation When Needed

Pass `disableCookieCache: true` to `getSession()` for critical operations requiring absolute current state verification.

### Customize Session Responses Judiciously

Custom session functions are called each time the session is fetched—avoid expensive computations in `customSession` callbacks.

## Multi-Device Management

### Support Device-Specific Revocation

Implement `listSessions()` and `revokeSession(token)` to enable users to sign out from specific devices while maintaining other active sessions.

### Provide Bulk Revocation Options

Expose `revokeOtherSessions()` and `revokeSessions()` for user control over account security.

## Related Standards

- See [error-handling.md](../../global/error-handling.md) for error patterns
- See [convex/best-practices.md](../convex/best-practices.md) for backend integration
