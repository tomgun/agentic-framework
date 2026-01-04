# Material Design System

**Philosophy**: Bold, graphic, intentional. Google's design language.

**Best for**: Android apps, Google-style web apps, consumer products

**Reference**: [Material Design 3](https://m3.material.io/)

---

## Color Palette

### Primary
- **Primary**: `#6200EE` (Material Purple)
- **Primary Variant**: `#3700B3`
- **On Primary**: `#FFFFFF` (text on primary)

### Secondary
- **Secondary**: `#03DAC6` (Teal)
- **Secondary Variant**: `#018786`
- **On Secondary**: `#000000`

### Background & Surface
- **Background**: `#FFFFFF`
- **Surface**: `#FFFFFF`
- **Error**: `#B00020`
- **On Background**: `#000000`
- **On Surface**: `#000000`
- **On Error**: `#FFFFFF`

---

## Typography

### Font Family
- **Roboto**: `"Roboto", sans-serif`

### Type Scale
- **H1**: `96px` / `6rem`, Light (300)
- **H2**: `60px` / `3.75rem`, Light (300)
- **H3**: `48px` / `3rem`, Regular (400)
- **H4**: `34px` / `2.125rem`, Regular (400)
- **H5**: `24px` / `1.5rem`, Regular (400)
- **H6**: `20px` / `1.25rem`, Medium (500)
- **Subtitle 1**: `16px` / `1rem`, Regular (400)
- **Subtitle 2**: `14px` / `0.875rem`, Medium (500)
- **Body 1**: `16px` / `1rem`, Regular (400)
- **Body 2**: `14px` / `0.875rem`, Regular (400)
- **Button**: `14px` / `0.875rem`, Medium (500), Uppercase
- **Caption**: `12px` / `0.75rem`, Regular (400)
- **Overline**: `10px` / `0.625rem`, Regular (400), Uppercase

---

## Spacing

**8dp Grid System**: All spacing is multiple of 8dp (8px)

- `8px` - Tiny gaps
- `16px` - Component padding
- `24px` - Medium spacing
- `32px` - Large spacing
- `48px` - Section spacing
- `64px` - Page margins

---

## Elevation (Shadows)

Material uses elevation to show hierarchy:

```css
/* 0dp - No elevation */
box-shadow: none;

/* 1dp - App bar, card resting */
box-shadow: 0px 1px 3px rgba(0,0,0,0.12), 0px 1px 2px rgba(0,0,0,0.24);

/* 2dp - Raised button resting */
box-shadow: 0px 3px 6px rgba(0,0,0,0.16), 0px 3px 6px rgba(0,0,0,0.23);

/* 4dp - App bar (scrolled), floating action button */
box-shadow: 0px 10px 20px rgba(0,0,0,0.19), 0px 6px 6px rgba(0,0,0,0.23);

/* 8dp - Menu, card (raised) */
box-shadow: 0px 14px 28px rgba(0,0,0,0.25), 0px 10px 10px rgba(0,0,0,0.22);

/* 16dp - Navigation drawer, modal bottom sheet */
box-shadow: 0px 19px 38px rgba(0,0,0,0.30), 0px 15px 12px rgba(0,0,0,0.22);
```

---

## Border Radius

- **Small components**: `4px` (chips, buttons)
- **Medium components**: `8px` (cards)
- **Large components**: `16px` (modals)
- **Full**: `50%` (FAB, avatars)

---

## Components

### Buttons

**Filled Button (Primary)**:
```css
background: #6200EE;
color: #FFFFFF;
padding: 10px 24px;
border-radius: 4px;
box-shadow: 0px 3px 6px rgba(0,0,0,0.16);
text-transform: uppercase;
letter-spacing: 1.25px;
font-weight: 500;
```

**Outlined Button**:
```css
background: transparent;
border: 1px solid #6200EE;
color: #6200EE;
padding: 10px 24px;
border-radius: 4px;
text-transform: uppercase;
```

**Text Button**:
```css
background: transparent;
color: #6200EE;
padding: 10px 16px;
border-radius: 4px;
text-transform: uppercase;
```

### Cards

```css
background: #FFFFFF;
border-radius: 8px;
padding: 16px;
box-shadow: 0px 1px 3px rgba(0,0,0,0.12);
```

### Text Fields

```css
background: #F5F5F5;
border: none;
border-bottom: 2px solid #E0E0E0;
padding: 16px 12px 8px;
border-radius: 4px 4px 0 0;

/* Focused */
border-bottom-color: #6200EE;
background: #EEEEEE;
```

### Floating Action Button (FAB)

```css
background: #6200EE;
color: #FFFFFF;
width: 56px;
height: 56px;
border-radius: 50%;
box-shadow: 0px 10px 20px rgba(0,0,0,0.19);
position: fixed;
bottom: 16px;
right: 16px;
```

---

## Motion

### Duration
- **Small**: `100ms` - Icon transitions
- **Medium**: `250ms` - Expanding panels
- **Large**: `300ms` - Page transitions

### Easing
- **Standard**: `cubic-bezier(0.4, 0.0, 0.2, 1)` - Default
- **Decelerate**: `cubic-bezier(0.0, 0.0, 0.2, 1)` - Entering elements
- **Accelerate**: `cubic-bezier(0.4, 0.0, 1, 1)` - Exiting elements

---

## Icons

**Material Icons**: Use [Material Icons](https://fonts.google.com/icons)

- **Size**: 24px default
- **Style**: Filled, Outlined, Rounded, Sharp, Two-tone

---

## Layout

### Responsive Grid
- **12-column grid**
- **8px gutters** (mobile), **24px gutters** (desktop)
- **Breakpoints**:
  - Mobile: 0-599px
  - Tablet: 600-1279px
  - Desktop: 1280px+

---

## Code Example (React + MUI)

```jsx
import { Button, Card, CardContent, Typography } from '@mui/material';

function Feature() {
  return (
    <Card elevation={2} sx={{ borderRadius: 2, p: 2 }}>
      <CardContent>
        <Typography variant="h5" component="h2" gutterBottom>
          Feature Title
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Feature description goes here...
        </Typography>
        <Button variant="contained" sx={{ mt: 2 }}>
          Learn More
        </Button>
      </CardContent>
    </Card>
  );
}
```

---

## References

- [Material Design 3](https://m3.material.io/) - Official guidelines
- [Material UI (MUI)](https://mui.com/) - React implementation
- [Material Design Icons](https://fonts.google.com/icons) - Icon library


