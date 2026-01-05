# Smoke Testing Checklist

**Purpose**: Verify the application ACTUALLY WORKS before claiming it's done. Don't rely on "it should work" - RUN IT and CHECK IT.

**When to use**: Before marking any feature as "working" or "complete", before commits that add/change user-facing functionality.

---

## ✅ Smoke Test Checklist

### 1. Application Starts Without Errors
- [ ] Run the application in the target environment (browser, mobile simulator, desktop, etc.)
- [ ] Application loads without errors (check console, logs, terminal)
- [ ] No red error screens, crashes, or blank pages
- [ ] All required assets load (images, fonts, sounds, etc.)

### 2. Basic User Flow Works
- [ ] Navigate to the main screen/page
- [ ] Perform the PRIMARY user action (e.g., click button, move piece, submit form)
- [ ] Verify the action produces the expected result
- [ ] Check for console errors during interaction

### 3. Feature-Specific Verification

**For games:**
- [ ] Render game board/scene correctly
- [ ] User can interact (click, drag, keyboard input)
- [ ] Game rules apply correctly (valid moves only, turn order, scoring)
- [ ] Game state updates visually (pieces move, score updates, etc.)

**For web apps:**
- [ ] Forms validate and submit
- [ ] Navigation works (routing, links)
- [ ] Data displays correctly
- [ ] User actions trigger expected responses

**For APIs/backends:**
- [ ] Server starts and responds to requests
- [ ] Endpoints return expected data/status codes
- [ ] Error handling works (try invalid inputs)

**For CLI tools:**
- [ ] Command runs without errors
- [ ] Help text displays correctly
- [ ] Basic commands work (create, read, update, delete)

### 4. Cross-Browser/Platform (If Applicable)
- [ ] Test in primary browser (Chrome/Safari/Firefox)
- [ ] Check mobile responsive view (if web)
- [ ] Test on actual device (if mobile app)

### 5. Console/Log Check
- [ ] No red errors in browser console
- [ ] No unhandled promise rejections
- [ ] No warning messages (or document them if acceptable)
- [ ] Network requests succeed (check Network tab)

---

## 🚨 CRITICAL: If Smoke Test Fails

**DO NOT commit. DO NOT claim feature is working. FIX IT FIRST.**

1. **Document the failure** in `JOURNAL.md`:
   - What you tested
   - What failed (exact error, behavior)
   - What you tried to fix it

2. **Debug systematically**:
   - Read the error message carefully
   - Check browser console / logs
   - Verify all dependencies are installed
   - Check for typos in code
   - Test logic in isolation (see "Testable Architecture" below)

3. **If stuck after 3-5 attempts**:
   - Add to `HUMAN_NEEDED.md` with:
     - What you tested
     - Error messages / screenshots
     - What you tried to fix it
   - Work on a different task

---

## 🏗️ Testable Architecture Principles

**CRITICAL LESSON**: Separate business logic from UI so you can test logic WITHOUT running the UI.

### Good Architecture (Testable)

**Game Example (Chess/Tetris/etc.)**:

```typescript
// ✅ GOOD: Pure game engine (no UI dependencies)
// src/engine/gameEngine.ts
export class GameEngine {
  constructor(private state: GameState) {}
  
  // Pure function: given state + move, return new state
  applyMove(move: Move): GameState {
    // Validate move
    if (!this.isValidMove(move)) {
      throw new Error("Invalid move");
    }
    
    // Apply game rules
    const newState = { ...this.state };
    newState.board[move.to.x][move.to.y] = newState.board[move.from.x][move.from.y];
    newState.board[move.from.x][move.from.y] = null;
    newState.currentPlayer = this.state.currentPlayer === 'black' ? 'white' : 'black';
    
    return newState;
  }
  
  isValidMove(move: Move): boolean {
    // Pure validation logic (no UI)
    const piece = this.state.board[move.from.x][move.from.y];
    if (!piece) return false;
    if (piece.color !== this.state.currentPlayer) return false;
    // ... more rules
    return true;
  }
}

// ✅ UNIT TEST (no UI needed!)
test('black cannot move during white turn', () => {
  const state = { currentPlayer: 'white', board: [...] };
  const engine = new GameEngine(state);
  const blackMove = { from: {x: 0, y: 0}, to: {x: 1, y: 0} };
  
  expect(engine.isValidMove(blackMove)).toBe(false);
});
```

```typescript
// ✅ GOOD: UI just calls engine
// src/ui/GameBoard.tsx
export const GameBoard = () => {
  const [gameState, setGameState] = useState(initialState);
  const engine = new GameEngine(gameState);
  
  const handleClick = (square: Position) => {
    try {
      const move = { from: selectedPiece, to: square };
      const newState = engine.applyMove(move);
      setGameState(newState);  // UI updates based on new state
    } catch (error) {
      showError(error.message);
    }
  };
  
  return <Board state={gameState} onClick={handleClick} />;
};
```

### Bad Architecture (Not Testable)

```typescript
// ❌ BAD: Game logic mixed with UI
// src/components/GameBoard.tsx
export const GameBoard = () => {
  const handleClick = (square) => {
    // Logic tightly coupled to UI state
    if (currentPlayer === 'white') {
      // ... DOM manipulation
      // ... direct state mutation
      // ... no way to test this without rendering UI!
    }
  };
};
```

---

## Architecture Patterns for Testability

### 1. Separate Engine from Renderer

**Engine**: Pure functions, no UI dependencies, fully testable
**Renderer**: Thin layer that calls engine and displays results

```
src/
  engine/          # Pure business logic (NO UI imports)
    gameEngine.ts
    rules.ts
    validation.ts
  ui/              # UI components (call engine)
    GameBoard.tsx
    Piece.tsx
```

### 2. Model-View-Controller (MVC)

**Model**: Data + business logic (testable)
**Controller**: Handles user input, calls model (testable)
**View**: Renders state (minimal logic)

### 3. Use Interfaces/Types

```typescript
// Define clear contracts
export interface GameEngine {
  applyMove(move: Move): GameState;
  isValidMove(move: Move): boolean;
  getValidMoves(position: Position): Position[];
}

// Easy to mock for testing
const mockEngine: GameEngine = {
  applyMove: jest.fn(),
  isValidMove: jest.fn().mockReturnValue(true),
  getValidMoves: jest.fn().mockReturnValue([]),
};
```

---

## Smoke Test Examples by Stack

### React/Next.js Web App
```bash
# 1. Start dev server
npm run dev

# 2. Open browser to http://localhost:3000
# 3. Check console (F12) - no red errors
# 4. Click primary action button
# 5. Verify expected behavior
# 6. Check Network tab - all requests succeed
```

### Python CLI
```bash
# 1. Run the command
python main.py --help

# 2. Try basic command
python main.py create test-item

# 3. Verify output is correct
python main.py list  # Should show test-item

# 4. Check for error messages
```

### Unity/Godot Game
```bash
# 1. Run in editor (Play button)
# 2. Check console for errors
# 3. Test game controls (WASD, mouse, etc.)
# 4. Verify game rules apply (collision, scoring, etc.)
# 5. Build and test standalone (if target is standalone)
```

### Mobile App
```bash
# 1. Start simulator/emulator
npm run ios  # or npm run android

# 2. App opens without errors
# 3. Tap primary actions
# 4. Check logs for errors
# 5. Test on actual device if possible
```

---

## When to Run Smoke Tests

**Always:**
- Before marking feature as "working"
- Before committing user-facing changes
- After refactoring UI or business logic
- When integrating new dependencies

**Optional but recommended:**
- After each significant change (every 30-60 min)
- Before ending work session
- Before creating a PR

---

## Automation

**For projects with CI/CD**, add automated smoke tests:

```yaml
# .github/workflows/smoke-test.yml
name: Smoke Test
on: [push, pull_request]

jobs:
  smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: npm install
      - name: Build
        run: npm run build
      - name: Start server
        run: npm start &
      - name: Wait for server
        run: sleep 10
      - name: Smoke test
        run: |
          curl -f http://localhost:3000 || exit 1
          # Add more checks
```

**For games/interactive apps**, use automated UI testing:
- Playwright (web)
- Appium (mobile)
- Unity Test Framework (Unity)

---

## Summary

**The lesson**: Don't trust "it should work" - RUN IT and VERIFY IT.

1. ✅ Run the application in the target environment
2. ✅ Check for errors (console, logs, terminal)
3. ✅ Test the primary user action
4. ✅ Verify expected behavior happens
5. ✅ Separate business logic from UI for easy testing

**If it doesn't work, it's NOT done. FIX IT FIRST.**

