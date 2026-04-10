# Unity Game Quality Knowledge

Deep domain expertise for building production games with Unity (C#).

## Update Loop Discipline

Unity has three main update methods. Using the wrong one causes physics bugs, input lag, or wasted CPU.

| Method | When | Use For |
|--------|------|---------|
| `Update()` | Every frame (variable rate) | Input, UI, non-physics movement |
| `FixedUpdate()` | Fixed timestep (default 50Hz) | Physics, rigidbody forces |
| `LateUpdate()` | After all Update calls | Camera follow, post-processing |

### Critical Rule
```csharp
// BAD: Physics in Update — depends on frame rate
void Update() {
    rb.AddForce(Vector3.forward * speed);  // Inconsistent at different FPS
}

// GOOD: Physics in FixedUpdate
void FixedUpdate() {
    rb.AddForce(Vector3.forward * speed);  // Consistent at all FPS
}

// GOOD: Input in Update, apply in FixedUpdate
private bool jumpPressed;

void Update() {
    if (Input.GetButtonDown("Jump")) jumpPressed = true;  // Capture input
}

void FixedUpdate() {
    if (jumpPressed) {
        rb.AddForce(Vector3.up * jumpForce, ForceMode.Impulse);
        jumpPressed = false;
    }
}
```

## GC Allocation in Hot Paths

The Unity garbage collector runs on the main thread and causes frame stutters. Avoid allocations in Update/FixedUpdate.

### Common Allocation Sources
```csharp
// BAD: String concatenation allocates
void Update() {
    scoreText.text = "Score: " + score;  // Allocates new string every frame
}

// GOOD: StringBuilder or cached string
private readonly StringBuilder sb = new StringBuilder(32);
void UpdateScoreDisplay() {  // Called only when score changes
    sb.Clear();
    sb.Append("Score: ");
    sb.Append(score);
    scoreText.text = sb.ToString();
}

// BAD: GetComponent every frame
void Update() {
    var rb = GetComponent<Rigidbody>();  // Slow lookup every frame
}

// GOOD: Cache in Awake
private Rigidbody rb;
void Awake() {
    rb = GetComponent<Rigidbody>();
}

// BAD: LINQ in hot paths
void Update() {
    var enemies = FindObjectsOfType<Enemy>()  // Allocates array
        .Where(e => e.IsAlive)                // Allocates iterator
        .OrderBy(e => e.Distance)             // Allocates
        .ToList();                            // Allocates list
}

// GOOD: Pre-allocated list, manual iteration
private readonly List<Enemy> activeEnemies = new List<Enemy>(64);
void Update() {
    activeEnemies.Clear();
    foreach (var enemy in allEnemies) {
        if (enemy.IsAlive) activeEnemies.Add(enemy);
    }
    // Sort in-place: no allocation
    activeEnemies.Sort((a, b) => a.Distance.CompareTo(b.Distance));
}
```

### NonAlloc Methods
Unity provides NonAlloc variants of expensive methods:
```csharp
// BAD: Allocates array
var hits = Physics.RaycastAll(ray, maxDistance);

// GOOD: Pre-allocated buffer
private readonly RaycastHit[] hitBuffer = new RaycastHit[32];
int count = Physics.RaycastNonAlloc(ray, hitBuffer, maxDistance);
for (int i = 0; i < count; i++) {
    ProcessHit(hitBuffer[i]);
}
```

## Object Pooling

```csharp
public class ObjectPool<T> where T : MonoBehaviour {
    private readonly Queue<T> pool = new Queue<T>();
    private readonly T prefab;
    private readonly Transform parent;

    public ObjectPool(T prefab, int initialSize, Transform parent = null) {
        this.prefab = prefab;
        this.parent = parent;
        for (int i = 0; i < initialSize; i++) {
            var obj = Object.Instantiate(prefab, parent);
            obj.gameObject.SetActive(false);
            pool.Enqueue(obj);
        }
    }

    public T Get() {
        T obj = pool.Count > 0 ? pool.Dequeue() : Object.Instantiate(prefab, parent);
        obj.gameObject.SetActive(true);
        return obj;
    }

    public void Return(T obj) {
        obj.gameObject.SetActive(false);
        pool.Enqueue(obj);
    }
}
```

## ScriptableObjects for Data

Use ScriptableObjects for game configuration instead of static classes or singletons:

```csharp
[CreateAssetMenu(fileName = "WeaponData", menuName = "Game/Weapon Data")]
public class WeaponData : ScriptableObject {
    public string weaponName;
    public float damage;
    public float fireRate;
    public float range;
    public GameObject projectilePrefab;
    public AudioClip fireSound;
}

// In weapon script:
public class Weapon : MonoBehaviour {
    [SerializeField] private WeaponData data;

    void Fire() {
        var projectile = Instantiate(data.projectilePrefab, ...);
        AudioSource.PlayClipAtPoint(data.fireSound, ...);
    }
}
```

Benefits:
- Designers can tweak values without code changes
- Data is an asset — version controlled, easy to duplicate
- No singleton/static coupling
- Can swap weapon data at runtime

## Async Scene Loading

```csharp
public class SceneLoader : MonoBehaviour {
    [SerializeField] private Slider progressBar;

    public async void LoadScene(string sceneName) {
        var operation = SceneManager.LoadSceneAsync(sceneName);
        operation.allowSceneActivation = false;

        while (!operation.isDone) {
            // Progress goes 0 to 0.9 (0.9 = loaded but not activated)
            float progress = Mathf.Clamp01(operation.progress / 0.9f);
            progressBar.value = progress;

            if (operation.progress >= 0.9f) {
                // Scene is loaded, wait for user input or timer
                await Task.Delay(500);  // Minimum loading screen time
                operation.allowSceneActivation = true;
            }

            await Task.Yield();
        }
    }
}
```

## Testing Unity Games

### EditMode Tests (Pure Logic)
```csharp
[TestFixture]
public class DamageCalculatorTests {
    [Test]
    public void CalculateDamage_CriticalHit_DoublesBase() {
        var result = DamageCalculator.Calculate(baseDamage: 10, isCritical: true);
        Assert.AreEqual(20, result);
    }

    [Test]
    public void CalculateDamage_ArmorReduces() {
        var result = DamageCalculator.Calculate(baseDamage: 100, armor: 25);
        Assert.AreEqual(75, result);
    }
}
```

### PlayMode Tests (Component Integration)
```csharp
[UnityTest]
public IEnumerator Player_TakesDamage_ReducesHealth() {
    var player = new GameObject().AddComponent<Player>();
    player.maxHealth = 100;
    player.currentHealth = 100;

    player.TakeDamage(30);

    yield return null;  // Wait one frame

    Assert.AreEqual(70, player.currentHealth);
}
```

### Manual Testing Checklist
- [ ] Game runs at target FPS on minimum spec hardware
- [ ] No visible GC stutters during gameplay (check Profiler)
- [ ] All scenes load without errors
- [ ] Save/load preserves game state correctly
- [ ] Audio plays correctly (music, SFX, spatial audio)
- [ ] UI scales correctly at different resolutions
- [ ] Input works on all target platforms (keyboard, gamepad, touch)
- [ ] Game handles minimizing/resuming without corruption

## Build Configuration

### Platform-Specific Settings
```
// Player Settings → Quality
Mobile: Medium quality, 30fps target
Desktop: High quality, 60fps target
WebGL: Medium quality, cap at screen refresh rate

// Player Settings → Other
Scripting Backend: IL2CPP (production), Mono (development)
API Compatibility: .NET Standard 2.1
Managed Stripping Level: Medium (reduces build size)
```

### Build Size Optimization
- Enable texture compression per platform (ASTC for mobile, BC7 for desktop)
- Use Addressables for asset management — load on demand
- Strip unused Engine code (Player Settings → Strip Engine Code)
- Audit Resources folder — everything in Resources is included in build
