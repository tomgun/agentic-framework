# Project Licensing Guide

**Purpose**: Help developers choose the right license for their project and understand how it affects dependencies, assets, and contributions.

---

## Why This Matters

**Your project's license affects**:
1. **What dependencies you can use** (GPL compatibility, etc.)
2. **What media assets are compatible** (CC-BY-NC not OK for commercial projects)
3. **How others can contribute** (CLA requirements, etc.)
4. **Commercial use** (Can others sell software based on yours?)
5. **Patent protection** (Apache 2.0 vs MIT)
6. **Copyleft requirements** (GPL vs permissive licenses)

---

## Quick Decision Guide

###  Choose if you want to...

**"Anyone can do anything, no restrictions"** → **MIT** or **Apache 2.0**

**"Anyone can use, but improvements must be shared back"** → **GPL-3.0** or **AGPL-3.0**

**"Free for open source, paid for commercial use"** → **Dual License** (GPL + Commercial)

**"I retain all rights, proprietary software"** → **Proprietary/Closed Source**

**"Public domain, no copyright"** → **Unlicense** or **CC0**

---

## License Options (Detailed)

### 1. MIT License ⭐ MOST POPULAR

**Summary**: Do whatever you want, just keep the license notice.

**Permissions**:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use

**Conditions**:
- ✅ Include license and copyright notice

**Limitations**:
- ❌ No liability protection
- ❌ No trademark protection
- ❌ No patent protection

**Best for**:
- Open source projects wanting maximum adoption
- Libraries and frameworks
- Projects wanting simple, business-friendly license
- Want to allow commercial use without restrictions

**Compatible dependencies**:
- ✅ MIT, Apache 2.0, BSD
- ✅ LGPL (for linking, not modifying)
- ⚠️  GPL (but your project becomes GPL)
- ❌ Proprietary/closed source libraries (need explicit permission)

**Examples**: React, Rails, Node.js, jQuery

**Recommended if**: You want maximum freedom for users, minimal restrictions.

---

### 2. Apache 2.0 License

**Summary**: Like MIT, but with explicit patent protection.

**Permissions**:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Patent grant (explicit)

**Conditions**:
- ✅ Include license and copyright notice
- ✅ State changes made to code
- ✅ Include NOTICE file if present

**Limitations**:
- ❌ No trademark use
- ❌ No liability

**Best for**:
- Projects from companies (patent protection matters)
- Libraries with potential patent issues
- Want permissive but legally stronger than MIT

**Compatible dependencies**: Same as MIT + explicit patent grant

**Examples**: Android, Apache web server, Kubernetes, TensorFlow

**Recommended if**: You want MIT-like freedom + patent protection (e.g., company-backed project).

---

### 3. GPL-3.0 (GNU General Public License) ⭐ COPYLEFT

**Summary**: Free to use, but any modifications/derivative works must also be GPL.

**Permissions**:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use

**Conditions**:
- ✅ Disclose source code
- ✅ License and copyright notice
- ✅ State changes
- ✅ **Same license** (copyleft - derivative works must be GPL!)

**Limitations**:
- ❌ No liability
- ❌ Can't be used in closed-source software

**Best for**:
- **Free Software** philosophy (freedom to study, modify, share)
- Ensuring improvements are shared with community
- Preventing proprietary forks
- Desktop applications, tools, utilities

**Compatible dependencies**:
- ✅ GPL-3.0, GPL-2.0 (with compatibility clause)
- ✅ LGPL, MIT, Apache (can include in GPL project)
- ❌ **CANNOT use proprietary libraries** (violates copyleft)
- ❌ Some BSD licenses (with advertising clause)

**Examples**: Linux kernel (GPL-2.0), Git, GIMP, WordPress, VLC

**Recommended if**: You want strong copyleft - all derivative works must be open source.

---

### 4. AGPL-3.0 (Affero GPL) ⭐ STRONGEST COPYLEFT

**Summary**: Like GPL, but also applies to network/cloud use (SaaS).

**Permissions**: Same as GPL-3.0

**Conditions**: Same as GPL-3.0, PLUS:
- ✅ **Network use = distribution** (must share source even if running as SaaS)

**Limitations**: Same as GPL-3.0

**Best for**:
- Web applications / SaaS
- Preventing "SaaS loophole" (running modified code on server without sharing)
- Ensuring cloud/network users can get source code

**Compatible dependencies**: Same as GPL-3.0

**Examples**: Mastodon, MongoDB (was AGPL before license change), Nextcloud

**Recommended if**: You're building a web app/SaaS and want to prevent proprietary cloud hosting without sharing code.

---

### 5. LGPL-3.0 (Lesser GPL)

**Summary**: Like GPL, but allows linking from non-GPL code.

**Permissions**: Same as GPL-3.0

**Conditions**: Similar to GPL, but **allows dynamic linking from non-GPL code**

**Best for**:
- Libraries that want to be used in commercial/closed-source projects
- Balance between freedom and adoption
- Want copyleft for the library, but allow proprietary apps to use it

**Compatible dependencies**: Same as GPL-3.0

**Examples**: Qt (LGPL option), GTK+, FFmpeg

**Recommended if**: You're building a library and want it to be used widely, but modifications to the library must be shared.

---

### 6. MPL-2.0 (Mozilla Public License)

**Summary**: File-level copyleft (modified files must be open, but can combine with proprietary code).

**Permissions**:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ✅ Patent grant

**Conditions**:
- ✅ Disclose source of **modified MPL files only**
- ✅ Can combine with proprietary code (in separate files)

**Best for**:
- Middle ground between permissive and copyleft
- Libraries wanting some protection but more permissive than GPL
- Want modifications shared but allow proprietary extensions

**Compatible dependencies**: Most (more permissive than GPL)

**Examples**: Firefox, Thunderbird, LibreOffice

**Recommended if**: You want weak copyleft - only modified files must be open source.

---

### 7. BSD Licenses (2-Clause, 3-Clause)

**Summary**: Very permissive, similar to MIT.

**Permissions**: Same as MIT

**Conditions**:
- ✅ Include license and copyright notice
- ✅ (3-Clause only) Cannot use project name for endorsement

**Best for**: Similar to MIT, slightly different wording

**Examples**: FreeBSD, OpenBSD, nginx

**Recommended if**: You want MIT-like freedom with different legal wording.

---

### 8. Unlicense / CC0 (Public Domain)

**Summary**: No copyright, truly public domain.

**Permissions**: Absolutely anything

**Conditions**: None

**Best for**:
- Tiny utilities, code snippets, examples
- Truly want zero restrictions or attribution
- Don't care about credit

**Examples**: SQLite (public domain), many code examples

**Recommended if**: You want to dedicate code to public domain (maximum freedom).

---

### 9. Dual License (e.g., GPL + Commercial)

**Summary**: Offer both open source (GPL) and commercial licenses.

**How it works**:
- Free users: Must comply with GPL (share derivative works)
- Paying users: Get proprietary license (can keep modifications closed)

**Best for**:
- Monetizing open source
- Companies building open-source core products
- Want copyleft but also commercial revenue

**Examples**: MySQL (was GPL + Commercial), Qt (LGPL + Commercial), MongoDB (was AGPL + Commercial)

**Recommended if**: You want open source community + commercial revenue stream.

---

### 10. Proprietary / Closed Source

**Summary**: All rights reserved, no open source.

**Permissions**: Only what you explicitly grant

**Best for**:
- Commercial software
- Don't want to share source code
- Want full control

**Compatible dependencies**:
- ✅ Permissive licenses (MIT, Apache, BSD)
- ⚠️  Commercial libraries (if you pay)
- ❌ GPL, AGPL (cannot use!)
- ⚠️  LGPL (only dynamic linking)

**Recommended if**: You're building commercial software and don't want to open source it.

---

## Comparison Table

| License | Type | Copyleft | Patent | Commercial Use | Closed Forks |
|---------|------|----------|--------|----------------|--------------|
| **MIT** | Permissive | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Apache 2.0** | Permissive | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **BSD** | Permissive | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **GPL-3.0** | Copyleft | ✅ Strong | ✅ Yes | ✅ Yes | ❌ No |
| **AGPL-3.0** | Copyleft | ✅ Strongest | ✅ Yes | ✅ Yes | ❌ No |
| **LGPL-3.0** | Weak Copyleft | ⚠️  Library | ✅ Yes | ✅ Yes | ⚠️  Partial |
| **MPL-2.0** | Weak Copyleft | ⚠️  File | ✅ Yes | ✅ Yes | ⚠️  Partial |
| **Unlicense/CC0** | Public Domain | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Proprietary** | Closed | N/A | N/A | Varies | N/A |

---

## Dependency Compatibility Matrix

### If Your Project is MIT or Apache 2.0:

| Dependency License | Compatible? | Notes |
|--------------------|-------------|-------|
| MIT, Apache, BSD | ✅ Yes | No issues |
| LGPL | ✅ Yes | Dynamic linking OK |
| GPL/AGPL | ⚠️  NO | Would make your project GPL! |
| Proprietary | ❌ No | Need explicit permission |

### If Your Project is GPL-3.0:

| Dependency License | Compatible? | Notes |
|--------------------|-------------|-------|
| MIT, Apache, BSD | ✅ Yes | Can include in GPL project |
| LGPL | ✅ Yes | No issues |
| GPL-3.0 | ✅ Yes | Same license |
| GPL-2.0 | ⚠️  Maybe | Check compatibility clause |
| Proprietary | ❌ NO | Violates GPL |

### If Your Project is AGPL-3.0:

Same as GPL-3.0, but also applies to SaaS/network use.

### If Your Project is Proprietary:

| Dependency License | Compatible? | Notes |
|--------------------|-------------|-------|
| MIT, Apache, BSD | ✅ Yes | No issues |
| LGPL | ⚠️  Yes | Dynamic linking only |
| GPL/AGPL | ❌ NO | Cannot use! |
| Proprietary | ⚠️  Maybe | Need commercial license |

---

## Media Asset Compatibility

### If Your Project is Open Source (MIT, Apache, GPL, etc.):

**Compatible asset licenses**:
- ✅ CC0 (Public Domain) - Best!
- ✅ CC-BY (Attribution required)
- ✅ CC-BY-SA (Share-alike)
- ✅ MIT, Apache (for code/fonts)
- ✅ OFL (Open Font License)

**Incompatible**:
- ❌ CC-BY-NC (Non-Commercial) - Conflicts with open source!
- ❌ CC-BY-ND (No Derivatives) - Can't modify
- ❌ "All Rights Reserved"

**See**: `.agentic/workflows/media_asset_workflow.md` for comprehensive asset sources.

### If Your Project is Proprietary:

**Compatible asset licenses**:
- ✅ CC0 (Public Domain)
- ✅ Commercial licenses (if you pay)
- ⚠️  CC-BY, CC-BY-SA (check if OK with proprietary use)
- ❌ CC-BY-NC (if commercial use)
- ❌ GPL-licensed assets (conflicts)

---

## Agent Workflow

### During Initialization

**Agent MUST ask**:

```
"What license do you want for this project?

**For Open Source:**
a) MIT - Maximum freedom (most popular)
b) Apache 2.0 - Like MIT + patent protection
c) GPL-3.0 - Free Software, copyleft (derivative works must be open)
d) AGPL-3.0 - Like GPL + applies to SaaS/cloud use
e) Other (LGPL, MPL, BSD, Unlicense)

**For Closed Source:**
f) Proprietary/Closed Source

**Not sure?** → Type 'help' for decision guide

Your choice (a/b/c/d/e/f/help):"
```

**If user chooses 'help'**:

```
**Quick Guide:**

Choose **MIT (a)** if:
- You want maximum adoption and freedom
- OK with others making closed-source forks
- Building libraries, tools, frameworks
- Most business-friendly

Choose **Apache 2.0 (b)** if:
- Like MIT but want patent protection
- Company-backed project
- More legally robust than MIT

Choose **GPL-3.0 (c)** if:
- You believe in Free Software philosophy
- Want to prevent proprietary forks
- OK with fewer commercial users
- Building desktop apps, tools

Choose **AGPL-3.0 (d)** if:
- Building web app / SaaS
- Want to prevent "SaaS loophole"
- Even network use = must share source

Choose **Proprietary (f)** if:
- Commercial software, no open source
- Want full control, no sharing

**Most common**: MIT (65%), Apache (13%), GPL (8%)
```

### Storing License Choice

**Create LICENSE file** at repo root:

```bash
# For MIT:
cp .agentic/templates/LICENSE-MIT LICENSE

# For GPL-3.0:
cp .agentic/templates/LICENSE-GPL-3.0 LICENSE

# etc.
```

**Update STACK.md**:

```markdown
## License

- **Project License**: MIT
- **Compatible Dependencies**: MIT, Apache 2.0, BSD, LGPL (dynamic linking)
- **Incompatible**: GPL, AGPL (would change our license)
```

**Update README.md**:

```markdown
## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
```

### During Development - Dependency Checks

**When agent wants to add a dependency**:

1. **Check dependency license** (package.json, requirements.txt, go.mod)
2. **Verify compatibility** with project license
3. **If incompatible, STOP and ask human**

**Example**:

```
Agent: "I want to use library XYZ for [feature].

⚠️  LICENSE ISSUE:
- Library XYZ is GPL-3.0
- Our project is MIT
- Adding GPL dependency would require us to change to GPL!

Options:
a) Find alternative library with compatible license
b) Change our project license to GPL-3.0 (MAJOR decision!)
c) Don't implement this feature

What should I do?"
```

### During Development - Asset Checks

**When agent sources media assets** (see `media_asset_workflow.md`):

1. **Check asset license**
2. **Verify compatibility** with project license
3. **If incompatible, warn**

**Example**:

```
Agent: "I found perfect background music on Incompetech:
'Epic Music Track' by Kevin MacLeod

⚠️  LICENSE NOTE:
- Music is CC-BY 4.0 (requires attribution)
- Our project is MIT (compatible!)
- Must add to assets/ATTRIBUTION.md

Proceed? (yes/no)"
```

---

## Files to Create

### LICENSE File (Required)

- **Location**: `LICENSE` (repo root)
- **Content**: Full license text
- **Source**: Get from https://choosealicense.com/

### STACK.md (Update)

```markdown
## License

- **Project License**: [MIT / Apache 2.0 / GPL-3.0 / etc.]
- **License File**: `LICENSE`
- **Compatible Dependencies**: [list compatible license types]
- **Incompatible Dependencies**: [list incompatible types - agent must avoid]
- **Asset Licensing**: See `assets/ATTRIBUTION.md` for all external assets
```

### README.md (Update)

```markdown
## License

This project is licensed under the [License Name] - see the [LICENSE](LICENSE) file for details.

### Dependencies

All dependencies are compatible with [License Name]. See `STACK.md` for details.

### Media Assets

External assets (images, sounds, etc.) have their own licenses. See `assets/ATTRIBUTION.md` for details.
```

### CONTRIBUTING.md (Optional, for open source projects)

```markdown
# Contributing

Thank you for your interest in contributing!

## License

By contributing to this project, you agree that your contributions will be licensed under the [Project License].

## Contributor License Agreement (CLA)

[If applicable - most projects don't need this]
```

---

## Common Questions

### Q: Can I change my license later?

**A**: Yes, but:
- ✅ Easy if you own all code (no contributors)
- ⚠️  Hard if you have many contributors (need permission from ALL)
- ⚠️  Some changes impossible (GPL → MIT requires rewriting GPL-licensed parts)
- **Best practice**: Choose carefully at start!

### Q: What if I want dual licensing?

**A**: You can! Common pattern:
- **Community edition**: GPL/AGPL (free, open source)
- **Enterprise edition**: Commercial license (paid, can be closed-source)
- Requires you to own all copyrights (or have CLA)

### Q: Do I need a Contributor License Agreement (CLA)?

**A**: Usually NO, unless:
- ✅ You want to dual-license (need to own all rights)
- ✅ You're a company (legal protection)
- ❌ Small project, single license → No CLA needed

### Q: What about code snippets from Stack Overflow?

**A**: Stack Overflow code is CC-BY-SA 4.0:
- ✅ Compatible with most licenses (cite the answer)
- ⚠️  Small snippets often considered "fair use"
- **Best practice**: Cite the SO answer URL in comments

---

## Integration Checklist

To fully implement license support:

- [ ] Add license templates to `.agentic/templates/`
  - [ ] LICENSE-MIT
  - [ ] LICENSE-APACHE-2.0
  - [ ] LICENSE-GPL-3.0
  - [ ] LICENSE-AGPL-3.0
  - [ ] (others as needed)
- [ ] Update `init_playbook.md` to ask about licensing
- [ ] Update `agent_operating_guidelines.md` with license checking rules
- [ ] Create `validate_licenses.py` tool to check dependency compatibility
- [ ] Update `STACK.template.md` with license fields
- [ ] Update `README.template.md` with license section
- [ ] Add license compatibility warnings to agents

**Status**: PLANNED (not yet implemented)

---

## Resources

- **Choose a License**: https://choosealicense.com/
- **SPDX License List**: https://spdx.org/licenses/
- **TL;DR Legal**: https://tldrlegal.com/
- **License Compatibility**: https://www.gnu.org/licenses/gpl-faq.html#AllCompatibility
- **GitHub Licensing Guide**: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository

