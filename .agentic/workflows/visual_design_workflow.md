# Visual Design Workflow

**Purpose**: Enable agents and developers to work with wireframes, screenshots, and visual designs for accurate UI/UX implementation.

---

## Current Status: NOT YET IMPLEMENTED

**This document outlines the PLANNED support for visual design workflows.**

The framework currently has NO specific guidance for:
- ❌ Importing wireframes as reference designs
- ❌ Generating designs automatically from descriptions
- ❌ Taking screenshots and annotating them
- ❌ Converting screenshots to editable designs

---

## Planned Features

### 1. Wireframe & Screenshot as Reference Design

**Goal**: Allow developers to reference visual designs during implementation.

**Implementation Plan**:

1. **Storage Location**: `design/` directory at repo root
   - `design/wireframes/` - Original wireframes (Figma exports, PDF, PNG)
   - `design/screenshots/` - Reference screenshots
   - `design/annotations/` - Annotated screenshots with improvement notes
   - `design/README.md` - Index of all design assets

2. **Linking to Features**:
   - Add `Design references:` field to feature specs
   - Example in `spec/FEATURES.md`:
     ```markdown
     ## F-0042: Login UI
     - Design references: design/wireframes/login-flow.png, design/screenshots/login-v2-annotated.png
     ```

3. **Agent Workflow**:
   - When implementing UI feature, agent reads linked design files
   - AI agents (Claude, GPT-4 Vision) can analyze images directly
   - Agent asks clarifying questions if design is ambiguous

**Example Usage**:
```markdown
# In spec/acceptance/F-0042.md

## Visual Design Reference

- Wireframe: design/wireframes/login-screen.png
- Interactive prototype: https://figma.com/file/ABC123

## Acceptance Criteria

- [ ] Layout matches wireframe spacing (20px padding, 16px gaps)
- [ ] Button colors match design system (primary: #3B82F6)
- [ ] Typography: Heading (24px bold), Body (16px regular)
- [ ] Responsive: Adapts to mobile (< 768px width)
```

### 2. Automatic Design Generation from Text

**Goal**: Generate wireframes/mockups from textual descriptions.

**Recommended Tools for Integration**:

1. **Uizard Autodesigner**
   - Input: Text description of UI
   - Output: Multi-screen wireframes
   - Use case: Rapid prototyping from requirements
   - Integration: Manual (agent suggests, human uses tool)

2. **MockFlow WireframePro**
   - AI-powered wireframe generation
   - Screenshot-to-wireframe conversion
   - Use case: Converting rough ideas to structured wireframes

3. **v0.dev (Vercel)**
   - Input: Text prompt
   - Output: React components with Tailwind CSS
   - Use case: Direct code generation from design descriptions
   - Integration: Agent can suggest prompts for v0.dev

**Agent Workflow**:
```
Human: "Create a dashboard with user stats, charts, and recent activity"

Agent:
1. Checks if design exists in design/wireframes/
2. If not, suggests:
   "I can implement this, but for best results, would you like to:
    a) Generate a wireframe first (I'll suggest a prompt for Uizard)
    b) Proceed with standard dashboard layout patterns
    c) Reference an existing dashboard design"
3. If human chooses (a), agent provides detailed prompt:
   "Suggested Uizard prompt: 'Dashboard with 3 stat cards at top,
   2 charts in middle row, activity feed in right sidebar, dark mode'"
4. Human generates design, saves to design/wireframes/dashboard-v1.png
5. Agent implements with design reference
```

### 3. Screenshot Annotation for Improvements

**Goal**: Take screenshots of product, annotate issues, pass to agent for fixes.

**Workflow**:

1. **Human Takes Screenshot**:
   - Screenshot product (browser, emulator, desktop app)
   - Save to `design/screenshots/issue-[F-####]-[date].png`

2. **Human Annotates** (using any tool):
   - **Mac**: Preview (built-in annotation)
   - **Windows**: Snipping Tool, Paint 3D
   - **Cross-platform**: Figma (import image, add comments), Skitch
   - Add arrows, circles, text highlighting issues
   - Save annotated version: `design/annotations/issue-[F-####]-[date]-annotated.png`

3. **Human Tells Agent**:
   ```
   "See design/annotations/issue-F-0042-2024-01-05-annotated.png
   Fix the issues highlighted"
   ```

4. **Agent Workflow**:
   - Read annotated screenshot (AI agents can see images)
   - Identify issues from annotations
   - Ask clarifying questions if ambiguous
   - Implement fixes
   - Update feature spec if design changed

**Example**:
```
Human screenshot shows:
- Red circle around button: "Padding too small"
- Arrow pointing to header: "Should be 32px not 24px"
- Yellow highlight on text: "Wrong color - should be #666"

Agent response:
"I see 3 issues in the annotated screenshot:
1. Button padding: Currently 8px, increase to 12px?
2. Header font size: Change from 24px to 32px
3. Text color: Change from #888 to #666

Implementing these fixes now..."
```

### 4. Screenshot-to-Editable Design Conversion

**Goal**: Convert existing product screenshots into editable designs for iteration.

**Recommended Tools**:

1. **Uizard Screenshot Scanner**
   - Upload screenshot → Get editable mockup
   - Use case: Redesigning existing UI

2. **Figma Plugins** (various)
   - HTML-to-Figma, Screenshot-to-Figma
   - Use case: Converting web apps to Figma for design iteration

**Workflow**:
```
1. Human: Screenshots existing feature
2. Human: Uploads to Uizard/Figma
3. Tool: Generates editable design
4. Human: Makes changes (colors, spacing, layout)
5. Human: Exports new design to design/wireframes/
6. Agent: Implements updated design
```

---

## File Structure

```
repo-root/
├── design/                    # Visual design assets
│   ├── README.md              # Index of all designs
│   ├── wireframes/            # Original wireframes
│   │   ├── login-flow.png
│   │   ├── dashboard-v1.png
│   │   └── settings-page.figma (link in README)
│   ├── screenshots/           # Reference screenshots
│   │   ├── competitor-app-login.png
│   │   └── old-dashboard-v0.png
│   └── annotations/           # Annotated screenshots with issues
│       ├── issue-F-0042-2024-01-05-annotated.png
│       └── improvement-dashboard-spacing.png
├── spec/
│   └── FEATURES.md            # Links to design/ files
```

---

## Agent Guidelines

**When implementing UI features**:

1. **Check for design references**:
   - Look in feature spec for `Design references:` field
   - If present, read/analyze the design files
   - Implement according to design specifications

2. **If no design exists**:
   - Ask human: "Should I follow standard patterns or do you have a design?"
   - Offer to suggest a design generation prompt
   - Document what was implemented for future reference

3. **When receiving annotated screenshots**:
   - Analyze all annotations carefully
   - List all issues found
   - Ask for clarification if annotations are ambiguous
   - Implement fixes systematically
   - Update design references if design changed

4. **Visual accuracy is NON-NEGOTIABLE**:
   - If design specifies 20px padding, use 20px (not "approximately 20px")
   - If design shows #3B82F6 blue, use #3B82F6 (not "similar blue")
   - If unsure about design intent, ASK (add to HUMAN_NEEDED.md)

---

## Tools Recommendation Summary

### For Wireframe Generation:
- **Uizard Autodesigner** - Text to wireframe
- **MockFlow WireframePro** - AI-powered wireframing
- **v0.dev** - Text to React components (direct code)

### For Screenshot Annotation:
- **Mac**: Preview (built-in, free)
- **Windows**: Snipping Tool, Paint 3D (built-in)
- **Cross-platform**: Figma (free tier), Skitch (free)

### For Screenshot-to-Design:
- **Uizard Screenshot Scanner** - Screenshot to editable mockup
- **Figma plugins** - Various screenshot import plugins

### For AI Vision Analysis:
- **Claude 3.5 Sonnet** - Excellent image analysis for agents
- **GPT-4 Vision** - Good image analysis for agents

---

## Integration Checklist

To fully implement visual design workflow support, the framework needs:

- [ ] Add `design/` directory to scaffold.sh
- [ ] Create `design/README.md` template
- [ ] Update `FEATURES.template.md` with `Design references:` field
- [ ] Update `agent_operating_guidelines.md` with visual design workflow
- [ ] Add "Visual Design Reference" section to acceptance template
- [ ] Update `DEVELOPER_GUIDE.md` with visual design workflow
- [ ] Create examples in example projects

**Status**: PLANNED (not yet implemented)

---

## Future Enhancements

- **Design system integration**: Link to Figma design tokens, CSS variables
- **Automated visual regression testing**: Percy, Chromatic, BackstopJS
- **Design-to-code automation**: Figma-to-React plugins, Anima
- **Real-time design sync**: Figma webhooks to notify agents of design changes

