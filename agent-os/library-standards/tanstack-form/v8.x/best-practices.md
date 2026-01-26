# TanStack Form Best Practices

## Context

Standards for building forms with TanStack Form. Apply these patterns for validation, field management, and form submission.

<conditional-block context-check="form-setup">
IF this Form Setup section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following form setup patterns

## Form Setup

### Basic Form Configuration

```typescript
import { useForm } from "@tanstack/react-form";

function ContactForm() {
  const form = useForm({
    defaultValues: {
      name: "",
      email: "",
    },
    onSubmit: async ({ value }) => {
      await submitContact(value);
    },
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        e.stopPropagation();
        form.handleSubmit();
      }}
    >
      {/* Fields */}
    </form>
  );
}
```

### Field Registration

```typescript
<form.Field
  name="email"
  validators={{
    onChange: ({ value }) =>
      !value.includes("@") ? "Invalid email" : undefined,
  }}
>
  {(field) => (
    <div>
      <label htmlFor={field.name}>Email</label>
      <input
        id={field.name}
        value={field.state.value}
        onBlur={field.handleBlur}
        onChange={(e) => field.handleChange(e.target.value)}
      />
      {field.state.meta.errors.length > 0 && (
        <span>{field.state.meta.errors.join(", ")}</span>
      )}
    </div>
  )}
</form.Field>
```

</conditional-block>

<conditional-block context-check="validation-patterns">
IF this Validation Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following validation patterns

## Validation Patterns

### Field-Level Validation

Apply validators directly to individual fields:

```typescript
<form.Field
  name="password"
  validators={{
    onChange: ({ value }) => {
      if (value.length < 8) {
        return "Password must be at least 8 characters";
      }
      return undefined;
    },
    onBlur: ({ value }) => {
      if (!/[A-Z]/.test(value)) {
        return "Password must contain uppercase letter";
      }
      return undefined;
    },
  }}
>
  {(field) => (/* ... */)}
</form.Field>
```

### Form-Level Validation

Validate across multiple fields:

```typescript
const form = useForm({
  defaultValues: {
    password: "",
    confirmPassword: "",
  },
  validators: {
    onChange: ({ value }) => {
      if (value.password !== value.confirmPassword) {
        return "Passwords do not match";
      }
      return undefined;
    },
  },
});
```

### Async Validation

Handle server-side checks:

```typescript
<form.Field
  name="username"
  validators={{
    onChangeAsync: async ({ value }) => {
      const exists = await checkUsernameExists(value);
      if (exists) {
        return "Username already taken";
      }
      return undefined;
    },
    onChangeAsyncDebounceMs: 500, // Debounce async validation
  }}
>
  {(field) => (/* ... */)}
</form.Field>
```

### Schema Validation with Adapters

Integrate with schema validation libraries:

```typescript
import { zodValidator } from "@tanstack/zod-form-adapter";
import { z } from "zod";

const userSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Invalid email address"),
});

const form = useForm({
  defaultValues: { name: "", email: "" },
  validators: {
    onChange: zodValidator(userSchema),
  },
});
```

</conditional-block>

<conditional-block context-check="error-handling">
IF this Error Handling section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following error handling patterns

## Error Display Patterns

### Show Errors After Touch

Only display errors after user interaction:

```typescript
{(field) => (
  <div>
    <input
      value={field.state.value}
      onBlur={field.handleBlur}
      onChange={(e) => field.handleChange(e.target.value)}
    />
    {field.state.meta.isTouched && field.state.meta.errors.length > 0 && (
      <span className="text-red-500">
        {field.state.meta.errors.join(", ")}
      </span>
    )}
  </div>
)}
```

### Form-Level Error Display

```typescript
<form.Subscribe selector={(state) => state.errors}>
  {(errors) =>
    errors.length > 0 && (
      <div className="bg-red-100 p-4 rounded">
        {errors.map((error, i) => (
          <p key={i}>{error}</p>
        ))}
      </div>
    )
  }
</form.Subscribe>
```

</conditional-block>

## Dynamic Fields

### Array Fields

Handle dynamic field lists:

```typescript
<form.Field name="items" mode="array">
  {(field) => (
    <div>
      {field.state.value.map((_, index) => (
        <form.Field key={index} name={`items[${index}].name`}>
          {(subField) => (
            <input
              value={subField.state.value}
              onChange={(e) => subField.handleChange(e.target.value)}
            />
          )}
        </form.Field>
      ))}
      <button
        type="button"
        onClick={() => field.pushValue({ name: "" })}
      >
        Add Item
      </button>
    </div>
  )}
</form.Field>
```

## Submission Handling

### Disable Submit During Validation

```typescript
<form.Subscribe
  selector={(state) => [state.canSubmit, state.isSubmitting]}
>
  {([canSubmit, isSubmitting]) => (
    <button type="submit" disabled={!canSubmit || isSubmitting}>
      {isSubmitting ? "Submitting..." : "Submit"}
    </button>
  )}
</form.Subscribe>
```

## Related Standards

- See [validation.md](../../global/validation.md) for validation approaches
- See [shadcn-ui/best-practices.md](../shadcn-ui/best-practices.md) for form UI components
