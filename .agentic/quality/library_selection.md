# Library Selection & Custom Implementation Guidelines

**Purpose**: Guide agents in choosing between using libraries vs. custom implementation, especially for domains with well-known standards (games, protocols, formats).

**Critical lesson**: Using a standard library for a non-standard variant can lock you into incompatible constraints.

---

## 🚨 CRITICAL: Custom Variants Need Custom Code

### The Problem (Real Example)

**Project**: Chess/Tetris hybrid game  
**AI Decision**: Use `chess.js` for move validation  
**Result**: WRONG - chess.js enforces standard chess rules, but the game has:
- Custom moves (Tetris-like mechanics)
- Pieces added one at a time (not standard starting position)
- Hybrid game rules (not pure chess)

**Impact**: Had to rip out chess.js and implement custom logic anyway, wasting time and introducing bugs.

### The Lesson

**If you're implementing a VARIANT or CUSTOM version of something standard, DON'T use libraries that enforce the standard.**

---

## Decision Framework

### Step 1: Identify the Domain Type

**Standard Implementation** (use library):
- Standard chess (follows FIDE rules exactly)
- Standard poker (follows standard rules)
- Standard HTTP (follows RFC)
- Standard Markdown (follows CommonMark spec)
- Standard payment flows (Stripe, PayPal)

**Custom/Variant Implementation** (custom code or low-level library):
- Chess variant (Chess960, custom pieces, hybrid rules)
- Poker variant (custom hand rankings, wild cards)
- Custom protocol (HTTP-like but different)
- Extended Markdown (custom syntax)
- Custom payment logic (split payments, custom flows)

### Step 2: Determine if Custom (Usually Obvious!)

**IMPORTANT**: In most cases, it's OBVIOUS if rules are custom. Don't waste time asking.

**Obvious custom implementations (DON'T ask, just use custom code):**
- "Chess/Tetris hybrid" → OBVIOUSLY custom
- "Chess variant" → Custom
- "Like chess but with X" → Custom
- "Custom game based on Y" → Custom
- "Poker with wild cards" → Custom
- "HTTP-like protocol" → Custom

**Obvious standard implementations (DON'T ask, use library):**
- "Chess game" (no mention of variants) → Standard (but confirm no custom rules planned)
- "Standard poker" → Standard
- "REST API" → Standard

**Ambiguous cases (ASK the user):**
- User just says "chess game" with no other context
- User says "card game" without specifying rules
- Requirements doc doesn't mention custom mechanics

**If you need to ask:**

```
"I'm planning to implement [feature]. I can:

a) Use [standard library] - enforces standard [chess/poker/HTTP/etc.] rules
   - Pros: Fast, well-tested, standard compliance
   - Cons: Hard to customize, locked into standard rules

b) Implement custom logic from scratch
   - Pros: Full control, easy to customize
   - Cons: More code, need to test ourselves

c) Use low-level library [e.g., board representation] - no rule enforcement
   - Pros: Some structure, full rule control
   - Cons: More work than (a), less than (b)

Does this game follow standard [chess] rules exactly, or does it have custom mechanics?"
```

**Only ask if genuinely unclear. Don't waste time on obvious cases.**

### Step 3: Choose Based on Customization Level

| Customization Level | Recommendation |
|---------------------|----------------|
| 0% - Exact standard | Use full-featured library |
| 1-20% - Minor tweaks | Use library, extend if possible |
| 20-50% - Significant changes | Use low-level library (data structures only) |
| 50%+ - Major custom logic | Implement from scratch |

---

## Examples by Domain

### Games

#### Standard Chess
```typescript
// ✅ GOOD: Use chess.js (standard rules)
import { Chess } from 'chess.js';
const game = new Chess();
game.move({ from: 'e2', to: 'e4' }); // Validates standard chess
```

#### Chess Variant (Custom Rules)
```typescript
// ✅ GOOD: Custom engine (custom rules)
class ChessTetrisEngine {
  // Implement your own validation
  isValidMove(move: Move): boolean {
    // Custom logic for hybrid game
    if (this.isTetrisPiece(move.piece)) {
      return this.validateTetrisMove(move);
    }
    return this.validateChessMove(move);
  }
}
```

```typescript
// ❌ BAD: Using chess.js for chess variant
import { Chess } from 'chess.js'; // This enforces standard chess!
// Won't work for Tetris pieces or custom starting positions
```

### Card Games

#### Standard Poker
```typescript
// ✅ GOOD: Use poker library (standard rules)
import { evaluateHand } from 'poker-evaluator';
const rank = evaluateHand(['AS', 'KS', 'QS', 'JS', 'TS']); // Royal flush
```

#### Custom Card Game
```typescript
// ✅ GOOD: Custom logic
class CustomCardEngine {
  // Your own hand evaluation
  evaluateHand(cards: Card[]): HandRank {
    // Custom scoring logic
  }
}
```

### Protocols

#### Standard HTTP
```typescript
// ✅ GOOD: Use fetch/axios (standard HTTP)
const response = await fetch('/api/users');
```

#### Custom Protocol
```typescript
// ✅ GOOD: Implement custom logic
class CustomProtocolClient {
  async request(endpoint: string): Promise<Response> {
    // Custom headers, encoding, flow
  }
}
```

---

## Keywords That Signal Custom Implementation (Don't Ask, Just Do Custom)

**If you see these words, it's CUSTOM - use custom code immediately:**

🔴 **"Hybrid"** - Chess/Tetris hybrid, poker/blackjack hybrid  
🔴 **"Variant"** - Chess variant, poker variant  
🔴 **"Custom"** - Custom rules, custom mechanics, custom game  
🔴 **"Like X but Y"** - "Like chess but pieces move like Tetris"  
🔴 **"Modified"** - Modified chess, modified poker  
🔴 **"Based on X with Y"** - "Based on chess with custom pieces"  
🔴 **"Non-standard"** - Non-standard protocol, non-standard rules  

**Example from real project:**
- User: "Chess/Tetris hybrid game"
- Keywords: "hybrid" (OBVIOUS custom)
- Correct action: Implement custom engine (NO asking needed)
- Wrong action: Ask "is this standard chess?" (obvious it's not!)

## Red Flags: When Standard Library is Wrong

🚩 **You need to bypass/disable library features**
```typescript
// ❌ BAD: Fighting the library
const game = new Chess();
game.disableValidation(); // If you need this, wrong library!
game.allowCustomPieces(); // Library doesn't support this? Wrong choice!
```

🚩 **You're monkey-patching or extending core classes**
```typescript
// ❌ BAD: Hacking the library
class CustomChess extends Chess {
  // Override half the methods to change behavior
  // This is fragile and will break on updates
}
```

🚩 **User says "like X but with custom Y"**
```
User: "It's like chess, but pieces move like Tetris blocks"
      ^^^^^^^^^         ^^^ CUSTOM RULES = CUSTOM CODE
```

🚩 **Documentation says "this enforces standard X"**
```
// chess.js documentation: "Enforces FIDE chess rules"
// ❌ If your rules aren't FIDE, don't use chess.js!
```

---

## When in Doubt: Ask First

**Template for architecture discussion:**

```markdown
## Architecture Decision: [Feature] Implementation

I need to decide how to implement [feature]. Here are the options:

### Option A: Use [Library Name]
**What it does**: [Brief description]
**Pros**:
- [Pro 1]
- [Pro 2]
**Cons**:
- [Con 1 - especially if it constrains customization]
**Best for**: Standard [chess/poker/HTTP] implementations

### Option B: Custom Implementation
**What it does**: Build logic from scratch
**Pros**:
- Full control over rules/behavior
- Easy to customize
**Cons**:
- More code to write and test
**Best for**: Custom/variant implementations

### My Recommendation
[Based on requirements, which option and why]

### Question for You
Does this project follow standard [X] rules exactly, or does it have custom mechanics?
If custom, what's different from the standard?
```

**Add to `HUMAN_NEEDED.md` and WAIT for response before implementing.**

---

## Post-Decision: Document the Choice

**Add to `spec/ADR.md` (Architecture Decision Record):**

```markdown
## ADR-####: Use Custom Game Engine (Not chess.js)

**Context**: Implementing chess/Tetris hybrid game

**Decision**: Implement custom game engine from scratch

**Rationale**:
- Game has custom rules (Tetris-like piece placement)
- Pieces added one at a time (not standard chess starting position)
- chess.js enforces FIDE rules (incompatible with our game)
- Need full control over move validation

**Alternatives Considered**:
- chess.js: Too constraining (enforces standard chess)
- Low-level board library: Could work, but simple enough to build ourselves

**Consequences**:
- More code to write and test
- Full flexibility for custom rules
- No dependency on external chess library
```

---

## Guidelines by Feature Type

### When to Use Libraries

✅ **Standard implementations**:
- Standard chess, poker, card games (with standard rules)
- HTTP clients, REST APIs
- Standard data formats (JSON, XML, CSV parsing)
- Standard protocols (WebSocket, OAuth, JWT)
- UI components (if design system matches)

✅ **Utility functions**:
- Date/time manipulation (date-fns, moment)
- Data validation (zod, yup)
- Testing (jest, vitest)
- Build tools (vite, webpack)

### When to Implement Custom

✅ **Custom/variant logic**:
- Game variants (custom rules, hybrid games)
- Custom business logic (domain-specific rules)
- Custom protocols (non-standard communication)
- Custom data structures (unique to your app)

✅ **Simple implementations**:
- If library is overkill (simple validation, basic math)
- If library is too opinionated
- If library is abandoned/unmaintained

---

## Checklist: Before Choosing a Library

- [ ] **Does the library enforce rules/standards?**
  - If yes: Do those EXACTLY match our requirements?
  - If no: Library might be okay

- [ ] **Can we easily customize it if needed?**
  - Check documentation for extensibility
  - Look for plugin/hook systems

- [ ] **Is this a standard or custom implementation?**
  - Standard → Library likely good
  - Custom → Library likely wrong

- [ ] **Have we discussed this with the user?**
  - If unclear, add to HUMAN_NEEDED.md and ask

- [ ] **Will this lock us in?**
  - Hard to switch later? Be extra careful

---

## Recovery: If You Chose Wrong

**Symptoms:**
- Constantly fighting the library
- Hacking/monkey-patching
- User says "that's not how it should work"

**Action:**
1. **Stop** - don't dig deeper
2. **Document** - Add to HUMAN_NEEDED.md:
   ```
   HN-####: Wrong library choice for [feature]
   - Type: architectural
   - Context: Using [library] but need custom [rules/logic]
   - Why human needed: Need decision on whether to:
     a) Continue hacking the library (risky)
     b) Switch to custom implementation (time cost)
   - Impact: Blocking further [feature] work
   ```
3. **Discuss** - Wait for user decision
4. **Refactor** - If switching, do it cleanly:
   - Write new implementation
   - Test thoroughly
   - Remove old library
   - Update ADR with lesson learned

---

## Summary

**Key Principle**: **Standard library for standard implementations, custom code for custom implementations.**

**Before choosing a library:**
1. **Check for obvious keywords**: hybrid, variant, custom, "like X but Y" → CUSTOM CODE (don't ask)
2. **If obvious**: Just proceed with custom implementation
3. **If ambiguous**: Ask user ("Does this follow standard X rules exactly?")
4. **Document**: Add ADR explaining choice

**Keywords that mean CUSTOM (don't ask, just use custom code):**
- Hybrid (Chess/Tetris hybrid)
- Variant (Chess variant)
- Custom (custom rules)
- "Like X but Y" (like chess but different moves)
- Modified, based on, non-standard

**Red flags:**
- Library enforces rules you don't need
- You're bypassing/disabling library features
- User says "like X but custom Y"

**When to ask**:
- Only if genuinely unclear
- User just says "chess game" with no context
- No mention of custom vs standard in requirements

**Don't waste time asking obvious cases!**

