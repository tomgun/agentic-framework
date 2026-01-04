# Game Development Support - Theory of Fun & Best Practices

**Purpose**: Comprehensive guide for developing fun, engaging, and polished games using Agentic AF.

**Status**: PLANNED (implementing comprehensive game development profiles)

---

## Current Game Support Status

### ✅ **Currently Available**:
- Media asset workflow (sprites, sounds, music from Kenney.nl, OpenGameArt, etc.)
- Quality profiles planned but not implemented (game_2d.sh, unity_game.sh, etc.)
- General testing and TDD guidelines

### ❌ **Missing** (Being Added):
- Game-specific quality profiles
- Theory of Fun / Game Design guidelines
- Physics library recommendations
- Game-specific testing (determinism, replay, etc.)
- 3D asset support
- OpenGL demo support

---

## Theory of Fun - Core Principles

### What Makes Games Fun?

Based on research from **Raph Koster** ("A Theory of Fun"), **Jesse Schell** ("The Art of Game Design"), and **Juice it or Lose it** (Martin Jonasson & Petri Purho):

### 1. **Learning & Mastery**

**Core Principle**: Fun = Learning = Pattern recognition + skill improvement

**In Practice**:
- Start easy, increase difficulty gradually
- Clear feedback on player actions
- Visible progress (scores, levels, achievements)
- New mechanics introduced one at a time

**Anti-Pattern**: 
- ❌ Tutorial dumps everything at once
- ❌ Difficulty spikes randomly
- ❌ No feedback on why player failed

**Agent Guideline**: 
- Design levels/challenges with learning curve
- Add tutorials that teach through play
- Provide immediate feedback for all actions

---

### 2. **Juiciness (Game Feel)**

**Core Principle**: Maximum output for minimum input = satisfying feel

**Elements of Juiciness**:
- **Screen shake** on impacts
- **Particle effects** for everything
- **Sound effects** for every action
- **Animation** - squash/stretch, anticipation, follow-through
- **Camera** movement and zoom
- **Time manipulation** - slow-mo on critical moments
- **Color flashes** for hits/success
- **Tweening** - smooth easing for movement

**Example - Jumping**:
```
❌ BAD: player.y += jumpSpeed
✅ GOOD: 
- Anticipation: Squash down sprite (0.1s)
- Jump: Stretch sprite + particle trail
- Peak: Time slows slightly
- Land: Squash sprite + screen shake + dust particles + sound
```

**Agent Guideline**:
- Every player action should have:
  1. Visual feedback (particles, animation, shake)
  2. Audio feedback (sound effects)
  3. Tactile feedback (vibration on mobile, screenshake)

---

### 3. **Clear Goals & Feedback**

**Core Principle**: Players must always know:
- What to do (clear goal)
- How they're doing (feedback)
- How close they are to winning (progress)

**In Practice**:
- **UI**: Health bars, score, ammo, timers always visible
- **Audio cues**: "Low health" sound, victory fanfare
- **Visual cues**: Flashing when damaged, glow on collectibles
- **Haptics**: Vibration on mobile for hits/success

**Agent Guideline**:
- Every game state should be visually obvious
- Never leave player confused about what to do next
- Add tutorials/hints if players get stuck

---

### 4. **Flow State (Goldilocks Zone)**

**Core Principle**: Challenge = Skills × 1.1 (slightly harder than comfortable)

**Too Easy** → Boring  
**Just Right** → Flow state (immersed, lose track of time)  
**Too Hard** → Frustrated

**In Practice**:
- Adaptive difficulty (if player fails 3 times, make easier)
- Multiple difficulty modes
- Optional challenges for advanced players
- Save points before hard sections

**Agent Guideline**:
- Playtest for difficulty balance
- Add difficulty settings
- Monitor player death/retry metrics

---

### 5. **Meaningful Choices**

**Core Principle**: Player decisions should matter

**Good Choices**:
- Risk vs Reward (take damage to grab powerup?)
- Resource management (spend gold now or save?)
- Build variety (different character builds, strategies)
- Exploration (take side path for secret?)

**Bad Choices**:
- Obvious optimal choice (no real decision)
- Choices with no consequences
- Irreversible choices without warning

**Agent Guideline**:
- Give players decisions, not just reactions
- Balance risk/reward
- Make different strategies viable

---

### 6. **Reward Schedules**

**Core Principle**: Variable rewards = dopamine = addictive

**Reward Types**:
- **Fixed**: Every 10 enemies = powerup (predictable)
- **Variable**: Random powerup drops (exciting)
- **Progressive**: Increasing rewards for streak
- **Surprise**: Rare epic drops

**In Practice**:
- Mix predictable and surprising rewards
- Short-term rewards (coins, points)
- Medium-term rewards (level completion, new abilities)
- Long-term rewards (achievements, unlocks)

**Agent Guideline**:
- Don't make players wait too long for rewards
- Use variable rewards for exciting moments
- Celebrate player victories (visual/audio fanfare)

---

### 7. **Aesthetic Beauty & Polish**

**Core Principle**: Visual/audio quality matters

**Polish Checklist**:
- Consistent art style
- Smooth animations (no jittery movement)
- Quality sound effects
- Appropriate music (intensity matches gameplay)
- No bugs or glitches visible to player
- Responsive controls (< 100ms input lag)

**Agent Guideline**:
- Prioritize "game feel" over features
- Test on target platform (60 FPS minimum)
- Get asset quality right (use Kenney, OpenGameArt, or commercial)

---

## Game-Specific Testing Best Practices

### 1. **Determinism Testing** (Critical for Physics Games)

**Why**: Physics bugs are often intermittent due to floating-point errors

**How**:
- **Fixed timestep**: Update physics at fixed rate (e.g., 60 Hz)
- **Replay system**: Record inputs, replay to verify same outcome
- **Unit tests**: Physics calculations should be deterministic

**Example**:
```python
def test_collision_deterministic():
    """Same initial state + same inputs = same outcome"""
    game1 = Game(seed=42)
    game2 = Game(seed=42)
    
    # Same inputs
    inputs = [Jump, MoveRight, Jump]
    
    result1 = game1.run(inputs)
    result2 = game2.run(inputs)
    
    assert result1 == result2  # Must be identical!
```

---

### 2. **Frame Rate Independence**

**Why**: Game should run same on 60Hz and 120Hz displays

**How**:
- Use delta time for all movement/animation
- Separate update rate from render rate
- Test at various frame rates

**Example**:
```python
# ❌ BAD: Tied to frame rate
player.x += 5  # Moves faster at 120 FPS!

# ✅ GOOD: Frame rate independent
player.x += speed * deltaTime  # Same speed at any FPS
```

---

### 3. **Performance Profiling**

**Critical Metrics**:
- **FPS**: 60 FPS minimum (16.67ms per frame)
- **Frame time**: Should never spike > 33ms (drops to 30 FPS)
- **Memory**: No memory leaks over time
- **Load times**: < 3 seconds for level loading

**Testing**:
```bash
# Profile frame time
python test_performance.py --profile-fps --duration=60s

# Memory leak detection
python test_performance.py --memory-profile --duration=300s

# Load time validation
pytest tests/test_load_times.py
```

---

### 4. **Input Recording & Replay**

**Why**: Reproduce bugs, create AI training data, verify determinism

**Implementation**:
```python
class InputRecorder:
    def record(self, input_event, timestamp):
        self.log.append((timestamp, input_event))
    
    def replay(self, game):
        for timestamp, event in self.log:
            game.process_input(event, timestamp)
```

**Use Cases**:
- Bug reproduction (player reports "bug at 2:34 in level 3")
- Automated testing (replay successful runs)
- Speedrun verification

---

### 5. **Physics Stability Testing**

**Common Issues**:
- Objects tunneling through walls (moving too fast)
- Jittery collision response
- Objects stuck in walls
- Explosive physics (objects fly away)

**Tests**:
```python
def test_no_tunneling():
    """Fast-moving objects shouldn't pass through walls"""
    bullet = Bullet(speed=1000)
    wall = Wall()
    
    result = physics.simulate(bullet, wall, timesteps=100)
    
    assert not bullet.passed_through(wall)

def test_stable_stacking():
    """Stacked objects should remain stable"""
    boxes = [Box() for _ in range(10)]
    stack = physics.stack(boxes)
    
    physics.simulate(stack, duration=10.0)
    
    assert stack.is_stable()  # No boxes fell
```

---

## 2D Game Development Support

### Recommended Stacks

#### **Web Games (HTML5/Canvas)**

**Frameworks**:
1. **Phaser 3** ⭐ RECOMMENDED
   - Feature-rich, great docs
   - Physics built-in (Arcade, Matter.js)
   - WebGL + Canvas renderer
   - Active community

2. **PixiJS**
   - Fast WebGL renderer
   - No game framework (more control)
   - Good for custom engines

3. **Three.js** (for 2.5D/3D)

**Physics Libraries**:
- **Matter.js** - Excellent 2D physics
- **P2.js** - Another solid option
- **Box2D** (via Box2D.js)

**Example Stack** (Phaser + TypeScript):
```json
{
  "dependencies": {
    "phaser": "^3.70.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/phaser": "^3.70.0",
    "vite": "^5.0.0"
  }
}
```

---

#### **Mobile Games (Native)**

**iOS**:
- **SpriteKit** (Swift) ⭐ RECOMMENDED
  - Native iOS framework
  - Great performance
  - Built-in physics (Box2D under hood)

**Android**:
- **libGDX** (Java/Kotlin)
  - Cross-platform
  - Excellent performance
  - Active community

**Cross-Platform**:
- **Unity** (2D mode) ⭐ MOST POPULAR
- **Godot** (open source)
- **React Native** (for simple games)

---

#### **Desktop Games**

**Cross-Platform Engines**:
- **Godot** ⭐ RECOMMENDED for 2D/3D (GDScript, C#, C++)
- **Unity** (for 3D or complex 2D)

**C++**:
- **SFML** ⭐ RECOMMENDED for pure 2D
- **SDL2** - Lower level, more control
- **Raylib** - Simple, modern

**Rust**:
- **Bevy** - ECS-based engine
- **Macroquad** - Simple, fast

---

### Visual Effects & Polish

**Essential Libraries for "Juiciness"**:

**Particle Systems**:
- Phaser: Built-in `Particles`
- Unity: Particle System
- Custom: Emit sprites with velocity + fade

**Screen Shake**:
```javascript
// Phaser example
function screenShake(intensity = 10, duration = 200) {
  camera.shake(duration, intensity);
}
```

**Tweening** (Smooth animations):
- Phaser: `scene.tweens.add()`
- Unity: DOTween
- Web: GSAP

**Post-Processing**:
- Bloom, chromatic aberration, vignette
- Phaser: Post-FX Pipeline
- Unity: Post Processing Stack

---

## 3D Game Development Support

### Unity Support

**Testing Guidelines**:
```csharp
// Unity Test Framework
[Test]
public void PlayerMovement_IsFrameRateIndependent() {
    var player = new Player();
    float deltaTime60Hz = 1f / 60f;
    float deltaTime120Hz = 1f / 120f;
    
    // Simulate 1 second at different frame rates
    for (int i = 0; i < 60; i++) {
        player.Update(deltaTime60Hz);
    }
    float pos60 = player.Position.x;
    
    player.Reset();
    
    for (int i = 0; i < 120; i++) {
        player.Update(deltaTime120Hz);
    }
    float pos120 = player.Position.x;
    
    Assert.AreEqual(pos60, pos120, 0.01f);
}
```

**Quality Checks**:
- Build validation (no errors)
- Frame rate profiling (Unity Profiler)
- Memory profiling
- Build size optimization

---

### Unreal Engine Support

**Testing Guidelines**:
- Use Unreal Automation System
- Functional tests for gameplay
- Performance tests with `stat unit`

---

### OpenGL/Custom Engines

**Support for Demos & Custom Engines**:

**Recommended Setup**:
- **Language**: C++ or Rust
- **Windowing**: GLFW or SDL2
- **Math**: GLM (C++) or cgmath (Rust)
- **Asset loading**: stb_image

**Quality Checks for OpenGL**:
```bash
# Frame rate test
./demo --benchmark --duration=60s --target-fps=60

# Memory leak check (Valgrind)
valgrind --leak-check=full ./demo

# Shader validation
glslangValidator shaders/*.vert shaders/*.frag
```

---

## 3D Asset Support

### Free 3D Model Sources

1. **Poly Haven** ⭐⭐⭐
   - 1,000+ models, HDRIs, textures
   - CC0 (Public Domain!)
   - PBR materials
   - https://polyhaven.com

2. **Sketchfab** (Filter by License)
   - Millions of models
   - Check license per model
   - Download glTF/FBX
   - https://sketchfab.com/3d-models?features=downloadable&sort_by=-likeCount

3. **OpenGameArt.org 3D**
   - Free game-ready 3D assets
   - Various licenses (check each)
   - https://opengameart.org/art-search?type=3d

4. **Kenney.nl 3D Assets**
   - CC0 (Public Domain!)
   - Low-poly style
   - https://kenney.nl/assets?q=3d

5. **Mixamo** (Adobe)
   - FREE rigged characters
   - FREE animations
   - https://www.mixamo.com

---

### Commercial 3D Asset Sources

1. **TurboSquid**
   - Largest 3D model marketplace
   - Professional quality
   - Pay-per-model

2. **Envato Elements** ($16.50/mo)
   - Unlimited 3D models
   - Game-ready assets
   - Best value!

3. **Unity Asset Store**
   - Unity-specific assets
   - Wide quality range

4. **Unreal Marketplace**
   - Unreal Engine assets
   - Professional quality

---

### Procedural 3D Generation

**AI Tools**:
- **Meshy.ai** - Text to 3D model
- **3DFY.ai** - Text to 3D
- **Luma AI** - Photo to 3D

**Blender + Python**:
```python
import bpy

# Procedural tree generation
def generate_tree(height=5, branches=8):
    # ... procedural generation code ...
    pass
```

---

### 3D File Formats

**Recommended Formats**:
- **glTF 2.0** (.gltf, .glb) - BEST for web/modern engines
- **FBX** - Unity/Unreal standard
- **OBJ** - Simple, universal (no animations)
- **COLLADA** (.dae) - Open format

**Conversion** (Blender):
```bash
# Convert FBX to glTF
blender --background --python convert_to_gltf.py -- model.fbx model.gltf
```

---

## Game Development Quality Profiles

### To Be Created:

1. **game_2d_web.sh** - Phaser/PixiJS validation
2. **game_2d_mobile.sh** - SpriteKit/libGDX validation
3. **game_unity.sh** - Unity project validation
4. **game_unreal.sh** - Unreal project validation
5. **game_opengl_demo.sh** - OpenGL demo validation

**Common Checks**:
- Frame rate consistency (60 FPS target)
- Memory usage (no leaks)
- Load times (< 3s per level)
- Physics stability (determinism tests)
- Input responsiveness (< 100ms lag)
- Asset optimization (texture sizes, polygon counts)

---

## Agent Guidelines for Game Development

### When Building a Game:

1. **Ask about game genre** (platformer, puzzle, shooter, etc.)
2. **Ask about target platform** (web, mobile, desktop)
3. **Recommend appropriate stack**:
   - Web → Phaser 3
   - Mobile → Unity or SpriteKit
   - Desktop → SFML or Unity
   - Custom/Demo → OpenGL + GLFW

4. **Apply Theory of Fun**:
   - Is there a clear learning curve?
   - Does every action have juicy feedback?
   - Are goals and progress clear?
   - Is difficulty balanced (flow state)?

5. **Implement Game Feel First**:
   - Particle effects for everything
   - Screen shake for impacts
   - Sound effects for all actions
   - Smooth animations (tweening)

6. **Test Rigorously**:
   - Frame rate independence
   - Physics determinism
   - Input replay
   - Performance profiling

7. **Iterate on Fun**:
   - Playtest frequently
   - Ask: "Is this fun? Why/why not?"
   - Polish core mechanics before adding features

---

## Integration Checklist

To fully implement game development support:

- [ ] Create game quality profiles (game_2d_web.sh, etc.)
- [ ] Add game-specific testing templates
- [ ] Create "Theory of Fun" checklist for agents
- [ ] Add Phaser/Unity/Godot to stack profiles
- [ ] Create OpenGL demo template
- [ ] Add 3D asset workflow to media_asset_workflow.md
- [ ] Create game design document templates
- [ ] Add determinism/replay testing examples

**Status**: PLANNED (comprehensive addition needed)

---

## Quick Start Examples

### Phaser 3 (Web Game):
```bash
npm create vite@latest my-game -- --template vanilla-ts
cd my-game
npm install phaser
# Agent: Set up Phaser game with player, physics, and collectibles
```

### Unity (2D/3D):
```bash
# Create new Unity project
# Agent: Set up player controller, camera, and testing framework
```

### OpenGL Demo:
```bash
# Clone OpenGL template
git clone https://github.com/[template] my-demo
# Agent: Implement fragment shader effects, audio reactivity
```

---

## Resources

- **Theory of Fun**: Raph Koster
- **Art of Game Design**: Jesse Schell (Deck of Lenses)
- **Game Feel**: Steve Swink
- **Juice it or Lose it**: Talk by Martin Jonasson & Petri Purho
- **Game Programming Patterns**: Robert Nystrom

