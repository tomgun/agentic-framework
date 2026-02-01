# Design Systems

**Purpose**: Reusable design specifications for consistent UI styling.

These templates provide design direction for visual projects, reducing design decisions agents need to make and ensuring consistent user experiences.

---

## Available Design Systems

- **[modern-minimal.md](modern-minimal.md)** - Clean, minimal, Tailwind-inspired design
- **[material-design.md](material-design.md)** - Google Material Design adaptation
- **[ios-human-interface.md](ios-human-interface.md)** - Apple HIG-inspired design

---

## How to Use

### During Project Initialization

When asked about design preferences in `init_playbook.md`:

1. Choose a design system from above (or say "none" for custom design)
2. Agent will reference it during UI implementation
3. Design system guides: colors, typography, spacing, components, motion

### For UI Implementation

When implementing UI features, agents should:
1. Check if design system is specified in `STACK.md` or `OVERVIEW.md`
2. Follow color palette, typography, spacing rules from the design system
3. Use component patterns from the design system
4. Deviate only when explicitly requested by human

### Customization

These are templates - customize them for your project:
1. Copy chosen design system to `docs/design-system.md`
2. Modify colors, fonts, spacing to match your brand
3. Add project-specific components
4. Reference from `CONTEXT_PACK.md` so agents know to use it

---

## When to Use Design Systems

**✅ Use when:**
- Building customer-facing products
- Team wants consistent visual language
- Multiple UI features being implemented
- Want to speed up UI development

**❌ Skip when:**
- CLI/backend-only projects
- Prototype/proof-of-concept (can add later)
- Designer provides custom mockups (use those instead)
- Very simple UI (1-2 screens)

---

## See Also

- Visual Design Workflow: `.agentic/workflows/visual_design_workflow.md`
- Wireframe/mockup guidelines
- Screenshot annotation process

