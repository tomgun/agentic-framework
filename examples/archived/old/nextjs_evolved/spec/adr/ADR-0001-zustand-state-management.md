# ADR-0001: Use Zustand for State Management

**Status**: Accepted  
**Date**: 2026-01-05  
**Deciders**: AI Agent, Human Developer  
**Technical Story**: Resolve localStorage synchronization issues (tech debt from v1.0.0)

## Context

Our initial v1.0.0 implementation used direct localStorage access for task persistence. This caused issues:

1. **Race conditions**: Multiple tabs could overwrite each other's changes
2. **No reactive updates**: Components didn't re-render when localStorage changed in another tab
3. **Boilerplate**: Every component had to handle load/save logic
4. **Testing difficulty**: Hard to mock localStorage in tests

## Decision Drivers

- Need reactive state across components
- Must persist to localStorage
- Want simple API (not Redux complexity)
- TypeScript support required
- Small bundle size (<10kb)

## Options Considered

### Option 1: React Context + useReducer (built-in)
**Pros:**
- No dependencies (0kb)
- Full control

**Cons:**
- Requires custom persistence logic
- Boilerplate (actions, reducer, context provider)
- No built-in middleware for localStorage sync

### Option 2: Redux Toolkit
**Pros:**
- Industry standard
- Great DevTools
- Middleware ecosystem

**Cons:**
- Large bundle (~40kb)
- Complex setup (slices, store, provider)
- Overkill for simple task app

### Option 3: Zustand
**Pros:**
- ✅ Tiny bundle (3.5kb)
- ✅ Simple API (one function call)
- ✅ Built-in persistence middleware
- ✅ TypeScript support
- ✅ No provider wrapper needed
- ✅ Great for Next.js App Router

**Cons:**
- Another dependency
- Less mature than Redux

## Decision

**Adopt Zustand with persistence middleware**

## Implementation

```typescript
// lib/store.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface Task {
  id: number;
  title: string;
  completed: boolean;
}

interface TaskStore {
  tasks: Task[];
  addTask: (title: string) => void;
  toggleTask: (id: number) => void;
  deleteTask: (id: number) => void;
}

export const useTaskStore = create<TaskStore>()(
  persist(
    (set) => ({
      tasks: [],
      addTask: (title) =>
        set((state) => ({
          tasks: [...state.tasks, { id: Date.now(), title, completed: false }]
        })),
      toggleTask: (id) =>
        set((state) => ({
          tasks: state.tasks.map((t) =>
            t.id === id ? { ...t, completed: !t.completed } : t
          )
        })),
      deleteTask: (id) =>
        set((state) => ({
          tasks: state.tasks.filter((t) => t.id !== id)
        }))
    }),
    { name: 'task-storage' }
  )
);
```

## Consequences

### Positive
- ✅ Resolved race conditions (Zustand handles sync)
- ✅ Reactive updates across tabs (storage event listener)
- ✅ Simpler component code (no manual load/save)
- ✅ Easier testing (can mock store)
- ✅ Bundle increase only +3.5kb

### Negative
- ❌ New dependency to maintain
- ❌ Team must learn Zustand API (but it's simple)

## Compliance

- Follows Next.js App Router best practices
- Compatible with React Server Components (client-side only)
- TypeScript types enforced

## Related

- Tech debt resolved from RETRO-2025-12-30
- Affects features: F-0001, F-0002, F-0003, F-0004, F-0005
- Enables future feature: F-0010 (multi-tab sync)

