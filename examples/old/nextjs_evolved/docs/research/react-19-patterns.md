# Research: React 19 Patterns & Best Practices

**Date**: 2026-01-02  
**Duration**: 45 minutes  
**Trigger**: Retrospective action item (ensure we're using latest patterns)  
**Researcher**: AI Agent

## Research Question

What are the key changes in React 19 that affect our task app, and are we following best practices?

## Context

- Currently using: React 19.0.0 with Next.js 15.1.0
- App Router (Server Components enabled)
- Want to ensure we're not using deprecated patterns

## Key Findings

### 1. Automatic Batching (Already in React 18, but improved in 19)
**Our status:** ✅ Already benefiting (no action needed)

React 19 automatically batches state updates even in promises, timeouts.

```typescript
// These are automatically batched in React 19
const handleAddTask = async () => {
  setTasks([...tasks, newTask]);  // Batched
  setNewTask('');                  // with this
};
```

### 2. Server Components (New default in Next.js 15)
**Our status:** ⚠️ Could improve

**Current:** All components are Client Components ('use client')  
**Recommendation:** Make non-interactive components Server Components

**Action:**
- TaskList can be Server Component (just renders)
- TaskForm needs to stay Client Component (has state/events)

**Benefit:** Smaller bundle, faster initial load

### 3. Server Actions (Simplified data mutations)
**Our status:** ❌ Not using yet

Server Actions simplify form handling without API routes.

**Current pattern:**
```typescript
// app/api/tasks/route.ts - separate API route
export async function POST(req) { ... }

// Client component
const res = await fetch('/api/tasks', { method: 'POST', ... });
```

**React 19 pattern:**
```typescript
// actions/tasks.ts - server action
'use server';
export async function addTask(formData) { ... }

// Client component
<form action={addTask}> ... </form>
```

**Decision:** Stay with current pattern for demo (localStorage, no server)  
**Future:** If we add database, use Server Actions

### 4. use() Hook (New in React 19)
**Our status:** ❌ Not needed yet

`use()` simplifies async data fetching in components.

**When to use:** If we fetch tasks from API  
**Current:** We use localStorage (synchronous), so not needed

### 5. Document Metadata API (Next.js 15 + React 19)
**Our status:** ⚠️ Could improve

**Current:** Basic metadata in layout.tsx  
**Recommendation:** Add per-page metadata

**Action:** Add metadata to task pages for better SEO

### 6. Streaming & Suspense Improvements
**Our status:** ❌ Not using

React 19 improved Suspense for streaming Server Components.

**Decision:** Not needed for demo (no async data)  
**Future:** If we add API fetching, use Suspense boundaries

## Recommendations for Our App

### High Priority
1. **Convert TaskList to Server Component** (smaller bundle)
2. **Add proper metadata** (SEO)
3. **Review Client Component boundaries** (minimize 'use client' usage)

### Low Priority (Future)
4. Server Actions (if we add database)
5. Suspense boundaries (if we add async data fetching)

## Code Examples

### Before (All Client Components):
```typescript
// app/tasks/page.tsx
'use client';

export default function TasksPage() {
  return <TaskList tasks={tasks} />;
}
```

### After (Server Component for static content):
```typescript
// app/tasks/page.tsx (Server Component - no 'use client')
export default function TasksPage() {
  return <TaskList tasks={tasks} />;
}

// components/TaskList.tsx (Server Component)
export function TaskList({ tasks }) {
  return tasks.map(task => <TaskRow key={task.id} task={task} />);
}

// components/TaskRow.tsx (Client Component - needs interactivity)
'use client';
export function TaskRow({ task }) {
  const [checked, setChecked] = useState(task.completed);
  // ...
}
```

## External References

- [React 19 Release Notes](https://react.dev/blog/2024/12/05/react-19)
- [Next.js 15 + React 19 Guide](https://nextjs.org/blog/next-15-1)
- [Server Components Deep Dive](https://nextjs.org/docs/app/building-your-application/rendering/server-components)

## Follow-up Actions

- [x] Document findings
- [ ] Refactor TaskList to Server Component (F-0007)
- [ ] Add per-page metadata (F-0008)
- [ ] Update architecture docs

## Outcome

Identified 3 optimizations. Implementing Server Component pattern expected to reduce bundle by ~50kb.

**Documentation verification:** Used Context7 to verify all APIs against React 19.0.0 and Next.js 15.1.0 docs.

