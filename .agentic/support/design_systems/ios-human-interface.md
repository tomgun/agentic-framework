# iOS Human Interface Guidelines Design System

**Philosophy**: Clarity, deference, depth. Apple's design language for iOS.

**Best for**: iOS/macOS apps, Apple-style web apps, elegant consumer products

**Reference**: [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

---

## Color Palette

### System Colors

**Primary (Tint Color)**: `#007AFF` (iOS Blue)

**Secondary Colors**:
- **Red**: `#FF3B30`
- **Orange**: `#FF9500`
- **Yellow**: `#FFCC00`
- **Green**: `#34C759`
- **Mint**: `#00C7BE`
- **Teal**: `#30B0C7`
- **Cyan**: `#32ADE6`
- **Blue**: `#007AFF`
- **Indigo**: `#5856D6`
- **Purple**: `#AF52DE`
- **Pink**: `#FF2D55`
- **Brown**: `#A2845E`

### Neutral Colors
- **Label**: `rgba(0, 0, 0, 1.0)` - Primary text
- **Secondary Label**: `rgba(60, 60, 67, 0.6)`
- **Tertiary Label**: `rgba(60, 60, 67, 0.3)`
- **Quaternary Label**: `rgba(60, 60, 67, 0.18)`

### Background Colors
- **System Background**: `#FFFFFF` (light), `#000000` (dark)
- **Secondary Background**: `#F2F2F7` (light), `#1C1C1E` (dark)
- **Tertiary Background**: `#FFFFFF` (light), `#2C2C2E` (dark)

### Dark Mode Support
All colors have dark mode variants. Use semantic colors, not fixed hex values.

---

## Typography

### Font Family
- **SF Pro**: System font on iOS/macOS
- **SF Pro Display**: Large sizes (>20pt)
- **SF Pro Text**: Small sizes (<20pt)
- **SF Mono**: Monospaced

### Text Styles

- **Large Title**: `34pt` / `41pt` line - Bold
- **Title 1**: `28pt` / `34pt` line - Regular
- **Title 2**: `22pt` / `28pt` line - Regular
- **Title 3**: `20pt` / `25pt` line - Regular
- **Headline**: `17pt` / `22pt` line - Semibold
- **Body**: `17pt` / `22pt` line - Regular
- **Callout**: `16pt` / `21pt` line - Regular
- **Subhead**: `15pt` / `20pt` line - Regular
- **Footnote**: `13pt` / `18pt` line - Regular
- **Caption 1**: `12pt` / `16pt` line - Regular
- **Caption 2**: `11pt` / `13pt` line - Regular

### Font Weights
- **Regular**: Default
- **Medium**: Slight emphasis
- **Semibold**: Strong emphasis
- **Bold**: Headings, important UI

---

## Spacing

**8pt Grid** (similar to Material, but more flexible):

- `4pt` - Tiny gaps
- `8pt` - Small spacing
- `16pt` - Standard spacing
- `24pt` - Medium spacing
- **32pt** - Large spacing
- `44pt` - Touch target minimum
- `64pt` - Section spacing

---

## Corner Radius

- **Small**: `8pt` - Buttons, pills
- **Medium**: `10pt` - Cells, cards
- **Large**: `12pt` - Sheets, modals
- **Extra Large**: `16pt` - Feature cards
- **Continuous**: iOS uses continuous curves (not simple radius)

---

## Shadows & Blur

iOS uses **blur and translucency** more than shadows:

**Translucent Backgrounds**:
```css
background: rgba(255, 255, 255, 0.85);
backdrop-filter: blur(20px);
-webkit-backdrop-filter: blur(20px);
```

**Subtle Shadows** (when needed):
```css
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
```

---

## Components

### Buttons

**Filled Button (Primary)**:
```css
background: #007AFF;
color: #FFFFFF;
padding: 11px 20px;
border-radius: 8px;
font-size: 17px;
font-weight: 600;
border: none;
```

**Tinted Button**:
```css
background: rgba(0, 122, 255, 0.15);
color: #007AFF;
padding: 11px 20px;
border-radius: 8px;
font-weight: 600;
```

**Plain Button**:
```css
background: transparent;
color: #007AFF;
padding: 11px 20px;
font-weight: 600;
```

### List Items / Cells

```css
background: #FFFFFF;
padding: 12px 16px;
border-bottom: 0.5px solid rgba(60, 60, 67, 0.29);
min-height: 44px; /* Touch target */

/* Chevron/Accessory */
→ icon aligned right
```

### Cards

```css
background: #FFFFFF;
border-radius: 10px;
padding: 16px;
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
```

### Sheets / Modals

```css
background: #FFFFFF;
border-radius: 12px 12px 0 0; /* Top corners only */
padding: 24px 16px;

/* Handle (optional) */
width: 36px;
height: 5px;
background: rgba(60, 60, 67, 0.3);
border-radius: 3px;
margin: 8px auto;
```

### Text Fields

```css
background: rgba(120, 120, 128, 0.12);
border: none;
border-radius: 10px;
padding: 12px 16px;
font-size: 17px;

/* Focused */
outline: 2px solid #007AFF;
outline-offset: -2px;
```

### Toggle / Switch

- **Width**: `51px`
- **Height**: `31px`
- **ON**: Green `#34C759`
- **OFF**: Gray `rgba(120, 120, 128, 0.16)`

---

## Navigation

### Navigation Bar
- **Height**: `44px` (compact), `96px` (large title)
- **Background**: Translucent with blur
- **Title**: Large Title (34pt) when scrolled up, shrinks to 17pt

### Tab Bar
- **Height**: `49px` + safe area
- **Icons**: 25x25pt template images
- **Selected**: Tint color (#007AFF default)
- **Unselected**: Gray `rgba(60, 60, 67, 0.6)`

---

## Motion & Animation

### Duration
- **Quick**: `0.25s` - Button taps, switches
- **Standard**: `0.35s` - View transitions
- **Slow**: `0.5s` - Modals, sheets

### Easing
- **Default**: `cubic-bezier(0.25, 0.1, 0.25, 1)` - iOS standard
- **Spring**: Use spring animations for physics-based motion

### Principles
- Motion feels physical and responsive
- Reduce motion respect (accessibility)
- Fluid, natural animations

---

## Icons

**SF Symbols**: Use [SF Symbols](https://developer.apple.com/sf-symbols/)

- **Sizes**: Small (13pt), Medium (17pt), Large (25pt)
- **Weights**: Match text weight
- **Rendering**: Template (tintable) or Multicolor

---

## Layout Principles

1. **Safe Areas**: Respect notch, home indicator, system UI
2. **Touch Targets**: Minimum 44x44pt
3. **Consistent Margins**: 16pt standard, 20pt for content
4. **Readability**: Max width ~600pt for text
5. **Adaptive**: Support all device sizes and orientations

---

## Accessibility

- **Dynamic Type**: Support all text sizes (accessibility sizes go larger)
- **VoiceOver**: Label all interactive elements
- **Color Contrast**: 4.5:1 minimum for text
- **Reduce Motion**: Provide alternatives to animations
- **Dark Mode**: Fully support, use semantic colors

---

## Code Example (SwiftUI)

```swift
struct FeatureCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feature Title")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Feature description goes here...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {}) {
                Text("Learn More")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
    }
}
```

---

## Code Example (React Native)

```jsx
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';

function FeatureCard() {
  return (
    <View style={styles.card}>
      <Text style={styles.title}>Feature Title</Text>
      <Text style={styles.description}>Feature description...</Text>
      <TouchableOpacity style={styles.button}>
        <Text style={styles.buttonText}>Learn More</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 5,
    elevation: 3,
  },
  title: {
    fontSize: 17,
    fontWeight: '600',
    color: '#000',
    marginBottom: 4,
  },
  description: {
    fontSize: 15,
    color: 'rgba(60, 60, 67, 0.6)',
    marginBottom: 12,
  },
  button: {
    backgroundColor: '#007AFF',
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '600',
  },
});
```

---

## References

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Icon library
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - iOS UI framework


