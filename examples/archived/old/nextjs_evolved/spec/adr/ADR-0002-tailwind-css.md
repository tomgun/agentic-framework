# ADR-0002: Use Tailwind CSS for Styling

**Status**: Accepted  
**Date**: 2026-01-06  
**Deciders**: AI Agent, Human Developer  
**Technical Story**: Standardize styling approach for consistency and maintainability

## Context

v1.0.0 used CSS Modules, which worked but had issues:

1. **Bundle bloat**: Separate CSS files for each component
2. **Naming conflicts**: Had to manually namespace classes
3. **No design system**: Every component reinvented colors/spacing
4. **Slow iteration**: Edit CSS file → save → see result (slow feedback)

## Decision Drivers

- Need consistent design system (colors, spacing, typography)
- Want fast iteration (no switching files)
- Must have good TypeScript autocomplete
- Should minimize bundle size
- Must work with Next.js App Router

## Options Considered

### Option 1: CSS Modules (current)
**Pros:**
- Already using it (no migration)
- Scoped styles (no conflicts)

**Cons:**
- No design system
- Verbose (separate .module.css files)
- Bundle grows with every component

### Option 2: styled-components / Emotion
**Pros:**
- CSS-in-JS (co-located styles)
- Dynamic styles based on props

**Cons:**
- Runtime cost (style injection)
- Doesn't work well with Server Components
- Larger bundle (~15kb)
- Setup complexity with Next.js App Router

### Option 3: Tailwind CSS
**Pros:**
- ✅ Utility-first (fast iteration)
- ✅ Built-in design system (colors, spacing)
- ✅ Great autocomplete (IntelliSense)
- ✅ Purges unused styles (small bundle)
- ✅ No runtime cost
- ✅ Works great with Server Components
- ✅ Industry standard

**Cons:**
- Class names can get long
- Learning curve (utility classes)

## Decision

**Adopt Tailwind CSS**

## Implementation

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

```typescript
// tailwind.config.ts
export default {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#3b82f6',
        secondary: '#8b5cf6'
      }
    }
  }
};
```

```typescript
// Before (CSS Modules):
import styles from './TaskRow.module.css';
<div className={styles.taskRow}>
  <span className={styles.title}>{task.title}</span>
</div>

// After (Tailwind):
<div className="flex items-center gap-3 p-4 border-b hover:bg-gray-50">
  <span className="text-lg text-gray-800">{task.title}</span>
</div>
```

## Consequences

### Positive
- ✅ Bundle size reduced by ~20kb (CSS purging)
- ✅ Faster dev iteration (no file switching)
- ✅ Consistent design (theme values)
- ✅ Great autocomplete (IntelliSense)
- ✅ Works perfectly with Server Components

### Negative
- ❌ Class names can be verbose
- ❌ Team must learn Tailwind utilities
- ❌ Migration effort (~4 hours to convert existing components)

## Compliance

- Follows Next.js App Router recommendations
- Compatible with React Server Components
- No runtime cost (build-time CSS generation)

## Migration Plan

1. Install Tailwind
2. Keep CSS Modules for now (gradual migration)
3. Convert components one-by-one as we touch them
4. Remove CSS Modules once all components migrated

## Related

- Identified in RETRO-2025-12-30 (consistency issues)
- Affects all UI features: F-0001 through F-0008
- Enables future: Dark mode (F-0011)

