# Tailwind CSS Best Practices

## Context

Standards for styling applications with Tailwind CSS. Apply these patterns for utility-first styling, component abstraction, and design system consistency.

<conditional-block context-check="utility-first">
IF this Utility-First section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following utility-first patterns

## Utility-First Styling

### Core Principle

Build components by combining single-purpose utility classes directly in markup:

```html
<div class="mx-auto flex max-w-sm items-center gap-x-4 rounded-xl bg-white p-6 shadow-lg">
  <img class="size-12 shrink-0" src="/img/logo.svg" alt="Logo" />
  <div>
    <div class="text-xl font-medium text-black">ChitChat</div>
    <p class="text-gray-500">You have a new message!</p>
  </div>
</div>
```

### Benefits Over Traditional CSS

- **Faster development**: No naming decisions needed
- **Safer changes**: Modifications only affect that element
- **Easier maintenance**: Self-documenting component styles
- **Portable code**: Copy/paste entire UI chunks
- **CSS stops growing**: Reusable utilities

### Why Not Inline Styles?

Utility classes provide:
- **Constrained design system**: Values from predefined theme
- **State variants**: `hover:`, `focus:`, `active:` prefixes
- **Responsive design**: Breakpoint prefixes like `sm:`, `md:`

```html
<button class="bg-sky-500 hover:bg-sky-700 disabled:hover:bg-sky-500">
  Save changes
</button>
```

</conditional-block>

<conditional-block context-check="state-responsive">
IF this State and Responsive section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following state and responsive patterns

## State and Responsive Design

### State Variants

Use variant prefixes for different states:

```html
<button class="bg-sky-500 hover:bg-sky-700 focus:ring-2 active:bg-sky-800 disabled:opacity-50">
  Save changes
</button>
```

### Responsive Design

Prefix utilities with breakpoint names (mobile-first):

```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3">
  <!-- 1 column on mobile, 2 on sm, 3 on lg -->
</div>
```

### Dark Mode

Use the `dark:` prefix:

```html
<div class="bg-white dark:bg-gray-800 text-gray-900 dark:text-white">
  <!-- Automatically adapts to dark mode -->
</div>
```

### Complex Selectors

Stack variants for complex conditions:

```html
<button class="dark:lg:hover:bg-indigo-600">
  <!-- Dark mode + lg breakpoint + hover -->
</button>

<!-- Group hover for styling based on parent state -->
<a href="#" class="group rounded-lg p-8">
  <span class="group-hover:underline">Read more</span>
</a>
```

</conditional-block>

<conditional-block context-check="arbitrary-values">
IF this Arbitrary Values section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following arbitrary value patterns

## Arbitrary Values

Use square bracket syntax for one-off values:

```html
<!-- Custom colors -->
<button class="bg-[#316ff6]">Sign in with Facebook</button>

<!-- Complex grid -->
<div class="grid grid-cols-[24rem_2.5rem_minmax(0,1fr)]">
  <!-- Custom column template -->
</div>

<!-- Calc values -->
<div class="max-h-[calc(100dvh-6rem)]">
  <!-- Dynamic height calculation -->
</div>
```

</conditional-block>

## Managing Duplication

### Use Loops for Repeated Elements

```jsx
<div class="flex -space-x-2 overflow-hidden">
  {contributors.map((user) => (
    <img
      key={user.id}
      class="inline-block h-12 w-12 rounded-full ring-2 ring-white"
      src={user.avatarUrl}
      alt={user.handle}
    />
  ))}
</div>
```

### Create Components for Reusable Patterns

```jsx
export function VacationCard({ img, imgAlt, eyebrow, title, pricing, url }) {
  return (
    <div>
      <img className="rounded-lg" src={img} alt={imgAlt} />
      <div className="mt-4">
        <div className="text-xs font-bold text-sky-500">{eyebrow}</div>
        <div className="mt-1 font-bold text-gray-700">
          <a href={url} className="hover:underline">{title}</a>
        </div>
        <div className="mt-2 text-sm text-gray-600">{pricing}</div>
      </div>
    </div>
  );
}
```

### Use `@layer components` for Simple Templates

When a component feels overkill:

```css
@import "tailwindcss";

@layer components {
  .btn-primary {
    border-radius: calc(infinity * 1px);
    background-color: var(--color-violet-500);
    padding-inline: var(--spacing-5);
    padding-block: var(--spacing-2);
    font-weight: var(--font-weight-semibold);
    color: var(--color-white);

    &:hover {
      background-color: var(--color-violet-700);
    }
  }
}
```

## Managing Style Conflicts

### Avoid Conflicting Classes

```jsx
// Avoid: Conflicting utilities
<div className="grid flex">...</div>

// Preferred: Conditional classes
<div className={gridLayout ? "grid" : "flex"}>...</div>
```

### Use Important Modifier When Needed

```html
<div class="bg-teal-500 bg-red-500!">
  <!-- bg-red-500 will apply due to ! modifier -->
</div>
```

## When to Use Inline Styles

1. **Dynamic values from APIs**:
```jsx
<button style={{ backgroundColor: buttonColor }}>
  {children}
</button>
```

2. **CSS variables for utility consumption**:
```jsx
<button
  style={{ "--bg-color": buttonColor }}
  className="bg-(--bg-color) hover:bg-(--bg-color-hover)"
>
  {children}
</button>
```

## Related Standards

- See [shadcn-ui/best-practices.md](../shadcn-ui/best-practices.md) for component patterns
- See [performance.md](../../global/performance.md) for bundle optimization
