# shadcn/ui Best Practices

## Context

Standards for building UI components with shadcn/ui. Apply these patterns for component composition, styling, and accessibility.

<conditional-block context-check="core-patterns">
IF this Core Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following core patterns

## Core Architecture

### Copy-Paste Distribution Model

shadcn/ui components are copied into your project rather than installed as npm packages. This provides:
- Full control over styling and dependencies
- No version lock-in
- Direct customization without overrides

### Two-Tier Component Structure

Components are built on accessible primitives (Radix UI or Base UI):
- **Base layer**: Unstyled, accessible primitives with ARIA patterns and keyboard navigation
- **shadcn layer**: Tailwind-styled components ready for use

</conditional-block>

<conditional-block context-check="variant-patterns">
IF this Variant Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following variant patterns

## Variant Patterns with CVA

Use Class Variance Authority (CVA) for managing style combinations through props:

```typescript
import { cva, type VariantProps } from "class-variance-authority";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
);
```

### Benefits of CVA

- Predictable variant combinations without manual class concatenation
- Type-safe variant props
- Easy to extend with new variants

</conditional-block>

<conditional-block context-check="composition">
IF this Composition section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following composition patterns

## Component Composition

### Prefer Composition Over Configuration

Build larger components from smaller, atomic primitives rather than adding props for every option:

```typescript
// Preferred: Composed components
<Dialog>
  <DialogTrigger asChild>
    <Button variant="outline">Open</Button>
  </DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Title</DialogTitle>
      <DialogDescription>Description</DialogDescription>
    </DialogHeader>
  </DialogContent>
</Dialog>

// Avoid: Monolithic prop-driven components
<Dialog
  title="Title"
  description="Description"
  triggerLabel="Open"
  triggerVariant="outline"
/>
```

### Use `asChild` for Polymorphic Rendering

The `asChild` prop allows components to render as different HTML elements:

```typescript
<Button asChild>
  <Link href="/dashboard">Go to Dashboard</Link>
</Button>
```

</conditional-block>

## Accessibility

### Built-In Accessibility

Radix UI primitives provide:
- ARIA attributes
- Keyboard navigation
- Focus management
- Screen reader support

### Maintain Accessibility When Customizing

When modifying components, preserve:
- Semantic HTML structure
- ARIA labels and descriptions
- Focus trap behavior in modals
- Keyboard interaction patterns

## Customization

### CSS-First Customization

- Use CSS variables for theming
- Apply Tailwind classes for styling
- Modify component source directly when needed

### Data Attributes for Styling Hooks

Components include data attributes for styling:

```typescript
<Button data-icon="inline-start">
  <Icon /> Label
</Button>
```

```css
[data-icon="inline-start"] {
  /* Custom icon positioning styles */
}
```

## Related Standards

- See [tailwind/best-practices.md](../tailwind/best-practices.md) for Tailwind patterns
- See [accessibility.md](../../frontend/accessibility.md) for accessibility guidelines
