# Next.js App Router Best Practices

## Context

Standards for building applications with Next.js App Router. Apply these patterns for routing, layouts, data fetching, and performance.

<conditional-block context-check="routing-patterns">
IF this Routing Patterns section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following routing patterns

## File-System Based Routing

### Folder Structure

- **Folders** define route segments that map to URL segments
- **Files** (`page`, `layout`, `loading`, `error`) create UI for segments

```
app/
├── layout.tsx        # Root layout (required)
├── page.tsx          # Home page (/)
├── about/
│   └── page.tsx      # About page (/about)
├── blog/
│   ├── layout.tsx    # Blog layout
│   ├── page.tsx      # Blog index (/blog)
│   └── [slug]/
│       └── page.tsx  # Blog post (/blog/[slug])
└── (marketing)/      # Route group (no URL impact)
    ├── pricing/
    └── features/
```

### Creating Pages

Export a React component as default from a `page` file:

```tsx
// app/page.tsx
export default function Page() {
  return <h1>Hello Next.js!</h1>;
}
```

### Creating Layouts

Layouts preserve state, remain interactive, and don't rerender on navigation:

```tsx
// app/layout.tsx
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <main>{children}</main>
      </body>
    </html>
  );
}
```

**Requirements**:
- Root layout is **required** and must contain `html` and `body` tags
- Layouts wrap child layouts via the `children` prop

</conditional-block>

<conditional-block context-check="dynamic-routes">
IF this Dynamic Routes section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following dynamic route patterns

## Dynamic Segments

### Basic Dynamic Routes

Wrap folder names in square brackets:

```tsx
// app/blog/[slug]/page.tsx
export default async function BlogPostPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const post = await getPost(slug);

  return (
    <div>
      <h1>{post.title}</h1>
      <p>{post.content}</p>
    </div>
  );
}
```

### Catch-All Segments

```
app/docs/[...slug]/page.tsx  →  /docs/a, /docs/a/b, /docs/a/b/c
```

### Optional Catch-All

```
app/docs/[[...slug]]/page.tsx  →  /docs, /docs/a, /docs/a/b
```

</conditional-block>

<conditional-block context-check="search-params">
IF this Search Params section already read in current context:
  SKIP: Re-reading this section
ELSE:
  READ: The following search param patterns

## Search Parameters

### Server-Side Usage

```tsx
// app/page.tsx
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const filters = (await searchParams).filters;
  // Use for database filtering, pagination
}
```

### Client-Side Usage

```tsx
"use client";

import { useSearchParams } from "next/navigation";

function FilterComponent() {
  const searchParams = useSearchParams();
  const sort = searchParams.get("sort");
  // Use for filtering already-loaded data
}
```

### Event Handlers

```tsx
function handleFilter() {
  const params = new URLSearchParams(window.location.search);
  params.set("sort", "newest");
  // No re-render triggered
}
```

</conditional-block>

## Navigation

### Link Component

Use `<Link>` for client-side navigation with prefetching:

```tsx
import Link from "next/link";

export default function Navigation() {
  return (
    <nav>
      <Link href="/about">About</Link>
      <Link href="/blog" prefetch={false}>
        Blog
      </Link>
    </nav>
  );
}
```

### Programmatic Navigation

```tsx
"use client";

import { useRouter } from "next/navigation";

function NavigateButton() {
  const router = useRouter();

  return (
    <button onClick={() => router.push("/dashboard")}>
      Go to Dashboard
    </button>
  );
}
```

## Type-Safe Props

Use global type helpers for type safety:

```tsx
// app/blog/[slug]/page.tsx
export default async function Page(props: PageProps<"/blog/[slug]">) {
  const { slug } = await props.params;
  return <h1>Blog post: {slug}</h1>;
}

// app/dashboard/layout.tsx
export default function Layout(props: LayoutProps<"/dashboard">) {
  return <section>{props.children}</section>;
}
```

**Note**: Types are generated during `next dev`, `next build`, or `next typegen`.

## Data Fetching

### Server Components (Default)

```tsx
// app/posts/page.tsx
async function getPosts() {
  const res = await fetch("https://api.example.com/posts");
  return res.json();
}

export default async function PostsPage() {
  const posts = await getPosts();
  return <PostList posts={posts} />;
}
```

### Caching and Revalidation

```tsx
// Revalidate every hour
const data = await fetch(url, { next: { revalidate: 3600 } });

// No caching
const data = await fetch(url, { cache: "no-store" });
```

## Related Standards

- See [tanstack-query/best-practices.md](../tanstack-query/best-practices.md) for client-side caching
- See [performance.md](../../global/performance.md) for optimization patterns
