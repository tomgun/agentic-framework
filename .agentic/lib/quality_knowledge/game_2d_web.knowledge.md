# 2D Web Game Quality Knowledge

Deep domain expertise for building 2D web games with Phaser 3, PixiJS, or similar frameworks.

## Frame Rate Independence

The most critical rule in game development: **never tie game logic to frame rate.**

### The Problem
```typescript
// BAD: Movement speed depends on FPS
update() {
  this.player.x += 5  // At 60fps = 300px/s, at 30fps = 150px/s
}

// GOOD: Use delta time
update(time: number, delta: number) {
  const speed = 300  // pixels per second
  this.player.x += speed * (delta / 1000)  // Same speed at any FPS
}
```

### Phaser 3 Delta Time
```typescript
class GameScene extends Phaser.Scene {
  update(time: number, delta: number) {
    // delta is milliseconds since last frame
    // time is total elapsed milliseconds
    const dt = delta / 1000  // Convert to seconds

    // All movement uses dt
    this.player.x += this.velocity.x * dt
    this.player.y += this.velocity.y * dt

    // All timers use dt
    this.spawnTimer -= dt
    if (this.spawnTimer <= 0) {
      this.spawnEnemy()
      this.spawnTimer = SPAWN_INTERVAL
    }
  }
}
```

### Common Violations
- `setInterval` / `setTimeout` for game logic (use Phaser's timer events)
- Animation frame counts instead of elapsed time
- Fixed-step physics without accumulator

## Object Pooling

Creating and destroying game objects (bullets, particles, enemies) causes garbage collection pauses that appear as frame stutters.

### Phaser 3 Group Pooling
```typescript
class BulletPool extends Phaser.Scene {
  private bullets: Phaser.Physics.Arcade.Group

  create() {
    this.bullets = this.physics.add.group({
      classType: Bullet,
      maxSize: 50,        // Pool size
      runChildUpdate: true,
    })
  }

  fire(x: number, y: number, direction: number) {
    const bullet = this.bullets.get(x, y) as Bullet
    if (bullet) {
      bullet.fire(direction)  // Reuse existing object
    }
    // If pool is exhausted, get() returns null — no allocation
  }
}

class Bullet extends Phaser.Physics.Arcade.Sprite {
  fire(direction: number) {
    this.setActive(true).setVisible(true)
    this.body.enable = true
    this.setVelocityX(Math.cos(direction) * BULLET_SPEED)
    this.setVelocityY(Math.sin(direction) * BULLET_SPEED)
  }

  preUpdate(time: number, delta: number) {
    super.preUpdate(time, delta)
    // Return to pool when off-screen
    if (!this.scene.cameras.main.worldView.contains(this.x, this.y)) {
      this.setActive(false).setVisible(false)
      this.body.enable = false
    }
  }
}
```

## Game State Machine

Use explicit states to prevent impossible combinations and simplify debugging.

```typescript
enum GameState {
  MENU,
  PLAYING,
  PAUSED,
  GAME_OVER,
  LEVEL_COMPLETE,
}

class GameScene extends Phaser.Scene {
  private state: GameState = GameState.MENU

  update(time: number, delta: number) {
    switch (this.state) {
      case GameState.PLAYING:
        this.updateGameplay(delta)
        break
      case GameState.PAUSED:
        // Don't update gameplay, but still animate UI
        break
      case GameState.GAME_OVER:
        this.updateGameOver(delta)
        break
    }
  }

  transition(newState: GameState) {
    // Validate transitions
    const valid: Record<GameState, GameState[]> = {
      [GameState.MENU]: [GameState.PLAYING],
      [GameState.PLAYING]: [GameState.PAUSED, GameState.GAME_OVER, GameState.LEVEL_COMPLETE],
      [GameState.PAUSED]: [GameState.PLAYING, GameState.MENU],
      [GameState.GAME_OVER]: [GameState.MENU, GameState.PLAYING],
      [GameState.LEVEL_COMPLETE]: [GameState.PLAYING, GameState.MENU],
    }

    if (!valid[this.state].includes(newState)) {
      console.warn(`Invalid transition: ${this.state} → ${newState}`)
      return
    }

    this.exitState(this.state)
    this.state = newState
    this.enterState(newState)
  }
}
```

## Asset Loading

### Preload Pattern (Phaser 3)
```typescript
class PreloadScene extends Phaser.Scene {
  preload() {
    // Show loading bar
    const bar = this.add.graphics()
    this.load.on('progress', (value: number) => {
      bar.clear()
      bar.fillStyle(0xffffff, 1)
      bar.fillRect(0, 270, 800 * value, 60)
    })

    // Load all game assets
    this.load.atlas('player', 'assets/player.png', 'assets/player.json')
    this.load.atlas('enemies', 'assets/enemies.png', 'assets/enemies.json')
    this.load.audio('bgm', ['assets/bgm.ogg', 'assets/bgm.mp3'])
    this.load.audio('sfx-hit', ['assets/hit.ogg', 'assets/hit.mp3'])
  }

  create() {
    this.scene.start('GameScene')
  }
}
```

### Texture Atlas Benefits
- One draw call per atlas instead of one per individual sprite
- Less texture switching = better GPU performance
- Use TexturePacker or free-tex-packer to create atlases

## Game Feel ("Juice")

Small details that make games feel responsive and satisfying:

### Screen Shake
```typescript
shakeCamera(intensity = 5, duration = 100) {
  this.cameras.main.shake(duration, intensity / 1000)
}
```

### Hit Freeze (Frame Pause)
```typescript
hitFreeze(duration = 50) {
  this.scene.pause()
  this.time.delayedCall(duration, () => this.scene.resume())
}
```

### Particle Burst
```typescript
createHitParticles(x: number, y: number) {
  const particles = this.add.particles(x, y, 'particle', {
    speed: { min: 50, max: 200 },
    angle: { min: 0, max: 360 },
    lifespan: 300,
    quantity: 10,
    scale: { start: 1, end: 0 },
    alpha: { start: 1, end: 0 },
    emitting: false,
  })
  particles.explode()
}
```

## Testing Games

### What to Test (Unit)
- Physics calculations (collision detection, velocity, gravity)
- Scoring and progression logic
- State machine transitions
- Input mapping
- Level generation algorithms

### What to Test (Visual / E2E)
- Game renders without errors
- Title screen loads
- Game responds to input (keyboard, touch)
- Score displays and updates
- Game over condition triggers correctly

### Playwright for Web Games
```typescript
test('game starts and renders', async ({ page }) => {
  await page.goto('http://localhost:3000')
  // Wait for Phaser to initialize
  await page.waitForSelector('canvas')
  // Take screenshot for visual comparison
  await expect(page.locator('canvas')).toHaveScreenshot('game-start.png')
})
```

## Performance Budget

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| FPS | 60 | <50 | <30 |
| Frame time | <16ms | >20ms | >33ms |
| JS bundle | <1MB | >2MB | >5MB |
| Total assets | <10MB | >20MB | >50MB |
| Memory | <100MB | >200MB | >500MB |
| Load time | <3s | >5s | >10s |
