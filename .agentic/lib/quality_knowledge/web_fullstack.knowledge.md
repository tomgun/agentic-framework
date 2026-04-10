# Full-Stack Web Quality Knowledge

Deep domain expertise for building production web applications with Next.js, Nuxt, Remix, or SvelteKit.

## Server Components vs Client Components (Next.js/React 19+)

The most common architectural mistake in modern Next.js apps is making too many client components.

**Default to server components.** Only add `'use client'` when you need:
- `useState`, `useReducer` (state)
- `useEffect`, `useLayoutEffect` (side effects)
- Browser-only APIs (window, localStorage, IntersectionObserver)
- Event handlers that need state (onClick with counter)

**Server components can**:
- Directly await database queries
- Read files from the filesystem
- Import server-only modules (node:fs, database drivers)
- Pass serializable props to client components

**Server components cannot**:
- Use React hooks (useState, useEffect, etc.)
- Add event handlers (onClick, onChange)
- Use browser APIs

### Pattern: Server Component with Client Island
```tsx
// page.tsx (server component — default)
import { db } from '@/lib/db'
import { LikeButton } from './like-button'  // client component

export default async function PostPage({ params }) {
  const post = await db.post.findUnique({ where: { id: params.id } })
  return (
    <article>
      <h1>{post.title}</h1>        {/* Server: no JS shipped */}
      <p>{post.content}</p>         {/* Server: no JS shipped */}
      <LikeButton postId={post.id} /> {/* Client: interactive */}
    </article>
  )
}
```

## Hydration Errors

Hydration mismatches are the #1 SSR debugging issue. They occur when server-rendered HTML differs from what the client renders.

### Common Causes
1. **Date/time formatting**: Server and client may be in different timezones
2. **Random values**: `Math.random()` or `crypto.randomUUID()` differ between renders
3. **Browser-only globals**: `window.innerWidth`, `navigator.userAgent`
4. **Invalid HTML nesting**: `<p>` inside `<p>`, `<div>` inside `<p>`

### Fix Pattern
```tsx
// WRONG: Different on server vs client
<p>Current time: {new Date().toLocaleString()}</p>

// RIGHT: Suppress hydration for dynamic content
'use client'
import { useState, useEffect } from 'react'

function ClientTime() {
  const [time, setTime] = useState<string>('')
  useEffect(() => { setTime(new Date().toLocaleString()) }, [])
  return <p>Current time: {time || 'Loading...'}</p>
}
```

## Data Fetching Patterns

### Server Components (preferred)
```tsx
// Direct database access — no API route needed
async function UserProfile({ userId }) {
  const user = await db.user.findUnique({ where: { id: userId } })
  return <div>{user.name}</div>
}
```

### Client Components (when interactivity needed)
```tsx
'use client'
import { useQuery } from '@tanstack/react-query'

function SearchResults({ query }) {
  const { data, isLoading } = useQuery({
    queryKey: ['search', query],
    queryFn: () => fetch(`/api/search?q=${query}`).then(r => r.json()),
  })
  // ...
}
```

### Key Rule
Never use `useEffect` + `fetch` for data that could come from a server component. Server components are faster (no client JS), more secure (no exposed API), and better for SEO.

## Bundle Size Management

### Warning Signs
- First Load JS > 200KB per route (check `next build` output)
- Large `node_modules` in client bundle (moment.js, lodash full)
- Images served without optimization (next/image handles this)

### Fixes
- **Dynamic imports**: `const Heavy = dynamic(() => import('./Heavy'), { ssr: false })`
- **Tree-shaking**: Import specific functions: `import { format } from 'date-fns'` not `import * as dateFns`
- **Analyze**: `ANALYZE=true npm run build` with `@next/bundle-analyzer`

## Authentication Patterns

- Use middleware for route protection — single enforcement point
- Store sessions in httpOnly cookies, not localStorage
- Use NextAuth.js / Auth.js or Clerk for production auth
- Never implement password hashing yourself — use bcrypt or argon2

## Testing Web Applications

### Unit Tests (Vitest)
Focus on: utility functions, custom hooks, API route handlers, validation schemas.
```bash
npx vitest run --reporter=dot
```

### Component Tests (Testing Library)
Focus on: user interactions, form validation, conditional rendering.
```tsx
import { render, screen, fireEvent } from '@testing-library/react'
test('form validates email', async () => {
  render(<SignupForm />)
  fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'invalid' } })
  fireEvent.click(screen.getByText('Submit'))
  expect(await screen.findByText('Invalid email')).toBeInTheDocument()
})
```

### E2E Tests (Playwright)
Focus on: auth flows, checkout, multi-page journeys, error states.
```bash
npx playwright test --project=chromium
```

## Error Handling

- Use `error.tsx` (Next.js) for route-level error boundaries
- Use `loading.tsx` for Suspense boundaries
- Use `not-found.tsx` for 404 pages
- Log errors to a service (Sentry, LogRocket) — don't rely on console
- Show user-friendly error messages — never expose stack traces in production
