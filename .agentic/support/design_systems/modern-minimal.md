# Modern Minimal Design System

**Philosophy**: Clean, functional, content-first. Inspired by Tailwind CSS, Vercel, Linear.

**Best for**: Web apps, dashboards, SaaS products, developer tools

---

## Color Palette

### Primary Colors
- **Brand**: `#0070f3` (vibrant blue)
- **Brand Dark**: `#0051cc`
- **Brand Light**: `#3291ff`

### Neutral Colors
- **Background**: `#ffffff` (white)
- **Surface**: `#fafafa` (off-white)
- **Border**: `#eaeaea`
- **Text Primary**: `#000000`
- **Text Secondary**: `#666666`
- **Text Tertiary**: `#999999`

### Semantic Colors
- **Success**: `#0070f3` (blue, not green - intentional)
- **Error**: `#ee0000`
- **Warning**: `#f5a623`
- **Info**: `#0070f3`

### Dark Mode (Optional)
- **Background**: `#000000`
- **Surface**: `#111111`
- **Border**: `#333333`
- **Text Primary**: `#ffffff`
- **Text Secondary**: `#888888`

---

## Typography

### Font Families
- **Sans**: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- **Mono**: `"SF Mono", Monaco, "Cascadia Code", "Roboto Mono", monospace`

### Font Sizes
- **xs**: `12px` / `0.75rem` - Captions, labels
- **sm**: `14px` / `0.875rem` - Body small, secondary text
- **base**: `16px` / `1rem` - Body text
- **lg**: `18px` / `1.125rem` - Lead paragraph
- **xl**: `20px` / `1.25rem` - H3
- **2xl**: `24px` / `1.5rem` - H2
- **3xl**: `30px` / `1.875rem` - H1
- **4xl**: `36px` / `2.25rem` - Hero heading

### Font Weights
- **Regular**: `400` - Body text
- **Medium**: `500` - Emphasized text, button labels
- **Semi-bold**: `600` - Headings, important UI elements

### Line Heights
- **Tight**: `1.25` - Headings
- **Normal**: `1.5` - Body text
- **Relaxed**: `1.75` - Long-form content

---

## Spacing Scale

Based on 4px grid:

```
4px (0.25rem) - Tiny
8px (0.5rem) - Extra small
12px (0.75rem) - Small
16px (1rem) - Base
24px (1.5rem) - Medium
32px (2rem) - Large
48px (3rem) - Extra large
64px (4rem) - XXL
96px (6rem) - XXXL
```

**Usage**:
- Padding inside components: 12-16px
- Margins between sections: 32-48px
- Page margins: 24-32px (mobile), 48-96px (desktop)

---

## Border Radius

- **None**: `0` - Tables, strict layouts
- **Small**: `4px` - Buttons, inputs, chips
- **Medium**: `8px` - Cards, modals
- **Large**: `12px` - Feature cards, images
- **Full**: `9999px` - Pills, avatars

---

## Shadows

```css
/* Subtle - Hover states, floating UI */
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);

/* Small - Cards, dropdowns */
box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);

/* Medium - Modals, popovers */
box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);

/* Large - Drawers, overlays */
box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
```

**Elevation Principle**: Higher elevation = larger shadow

---

## Components

### Buttons

**Primary**:
```css
background: #0070f3;
color: #ffffff;
padding: 12px 24px;
border-radius: 4px;
font-weight: 500;
border: none;
cursor: pointer;
```

**Secondary**:
```css
background: transparent;
color: #000000;
padding: 12px 24px;
border: 1px solid #eaeaea;
border-radius: 4px;
font-weight: 500;
cursor: pointer;
```

**States**:
- Hover: Slightly darker background (`filter: brightness(0.9)`)
- Active: Even darker (`filter: brightness(0.8)`)
- Disabled: Opacity 0.5, no pointer events

### Inputs

```css
background: #ffffff;
border: 1px solid #eaeaea;
border-radius: 4px;
padding: 12px 16px;
font-size: 14px;
transition: border-color 0.2s;

/* Focus */
border-color: #0070f3;
outline: none;
box-shadow: 0 0 0 3px rgba(0, 112, 243, 0.1);
```

### Cards

```css
background: #ffffff;
border: 1px solid #eaeaea;
border-radius: 8px;
padding: 24px;
box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
```

### Modals

```css
background: #ffffff;
border-radius: 8px;
padding: 32px;
max-width: 600px;
box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);

/* Overlay */
background: rgba(0, 0, 0, 0.5);
backdrop-filter: blur(4px);
```

---

## Motion & Animation

### Durations
- **Fast**: `150ms` - Hover, focus states
- **Normal**: `250ms` - UI transitions, reveals
- **Slow**: `400ms` - Page transitions, complex animations

### Easing
- **Default**: `cubic-bezier(0.4, 0, 0.2, 1)` - Most animations
- **Decelerate**: `cubic-bezier(0, 0, 0.2, 1)` - Enter animations
- **Accelerate**: `cubic-bezier(0.4, 0, 1, 1)` - Exit animations

### Principles
- Motion should be purposeful, not decorative
- Faster animations for small changes
- Respect `prefers-reduced-motion` media query

---

## Layout Principles

1. **Mobile First**: Design for mobile, enhance for desktop
2. **Consistent Spacing**: Use the spacing scale religiously
3. **White Space**: More is better - let content breathe
4. **Grid**: 12-column grid for complex layouts
5. **Max Width**: Content containers: 640px (text), 1200px (UI)

---

## Accessibility

- **Color Contrast**: Minimum 4.5:1 for text, 3:1 for UI components
- **Focus Indicators**: Always visible, high contrast
- **Touch Targets**: Minimum 44x44px
- **Keyboard Navigation**: All interactive elements reachable
- **Screen Readers**: Semantic HTML, ARIA labels where needed

---

## Code Examples

**Button (React + Tailwind)**:
```jsx
<button className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-6 rounded transition-colors">
  Get Started
</button>
```

**Card (React + Tailwind)**:
```jsx
<div className="bg-white border border-gray-200 rounded-lg p-6 shadow-sm hover:shadow-md transition-shadow">
  <h3 className="text-xl font-semibold mb-2">Feature Title</h3>
  <p className="text-gray-600">Feature description...</p>
</div>
```

---

## References

- [Tailwind CSS](https://tailwindcss.com/) - Utility-first CSS
- [Vercel Design](https://vercel.com/design) - Clean, minimal web design
- [Linear](https://linear.app/) - Modern SaaS UI patterns


