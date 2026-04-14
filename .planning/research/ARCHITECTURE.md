# Architecture Patterns: Enemy AI Integration

**Domain:** 2D space shooter — enemy AI layered onto existing Body/Ship hierarchy
**Researched:** 2026-04-11
**Confidence:** HIGH — all conclusions drawn from direct inspection of production source files

---

## Existing Hierarchy (Confirmed)

```
RigidBody2D
  └─ Body            (components/body.gd)         health, die(), spawn_parent, item_dropper
       └─ MountableBody  (components/mountable-body.gd)  Action enum, do(), mount_weapon(), mounts[]
            └─ Ship      (components/ship.gd)           picker Area2D, inventories, coin/ammo/weapon pickup
                 ├─ PlayerShip  (components/player-ship.gd)   empty stub — movement via PropellerMovement Node
                 └─ EnemyShip   (components/enemy-ship.gd)    empty stub — ready to be built out
```

`PropellerMovement` (components/propeller-movement.gd) is a **Node** (not part of the class hierarchy). It reads `Input.is_action_pressed(action)` each `_physics_process` frame and calls `body.apply_force(...)`. Enemies never need this node in their scenes.

---

## Recommended Architecture

### 1. State Machine — Lives in EnemyShip (base class)

Place the state machine enum and the virtual transition methods in `EnemyShip`, not in per-type scripts. Rationale:

- All five enemy types share the same 8-state vocabulary; duplicating the enum across types creates drift.
- Per-type scripts override only the methods relevant to their behaviour; unimplemented states fall through to no-op defaults in the base.
- One state variable (`current_state`) is readable by WaveManager and debug overlays from a single known type.

```gdscript
class_name EnemyShip
extends Ship

enum State {
    IDLING, SEEKING, LURKING, FIGHTING, FLEEING,
    PATROLLING, EVADING, ESCORTING
}

var current_state: State = State.IDLING
var target: Node2D = null          # usually the PlayerShip node
var fire_timer: Timer              # created in _ready()

func _ready() -> void:
    fire_timer = Timer.new()
    fire_timer.one_shot = false
    add_child(fire_timer)
    fire_timer.timeout.connect(_on_fire_timer_timeout)
    super()                        # Ship._ready() connects body_entered + picker

func _physics_process(delta: float) -> void:
    _tick_state(delta)

# --- Virtual hooks (override in concrete types) ---
func _tick_state(_delta: float) -> void: pass
func _enter_state(_new: State) -> void: pass
func _exit_state(_old: State) -> void: pass

func transition(new_state: State) -> void:
    if new_state == current_state:
        return
    _exit_state(current_state)
    current_state = new_state
    _enter_state(current_state)

# --- Fire hook (override in concrete types) ---
func _on_fire_timer_timeout() -> void: pass
```

Per-type scripts (e.g. `prefabs/beeliner/beeliner.gd`) extend `EnemyShip`, override `_tick_state`, `_enter_state`, `_exit_state`, and `_on_fire_timer_timeout`. They do not touch the enum or the `transition()` dispatcher.

### 2. Enemy Movement — apply_force Directly on Self

`PropellerMovement` calls `body.apply_force(...)`. Enemies replicate this pattern inline in `_tick_state`, calling `apply_force(...)` on `self` (since `EnemyShip` IS a `RigidBody2D` via inheritance). No wrapper component is needed.

Reference: `PropellerMovement._physics_process` (components/propeller-movement.gd line 12–24) — the full call is:

```gdscript
body.apply_force(
    profile.vector.rotated(body.rotation) * profile.thrust * delta * 100,
    position.rotated(body.rotation)
)
```

Enemies call the equivalent directly:

```gdscript
# Inside EnemyShip._tick_state or an override:
var dir = (target.global_position - global_position).normalized()
apply_force(dir * thrust * delta, Vector2.ZERO)
```

`linear_damp` on the `RigidBody2D` node (ship-bfg-23 uses `1.0`) provides automatic deceleration; set per-enemy-type in the scene inspector.

### 3. Detection — Area2D as Child Node in Scene

Add a `DetectionArea` (Area2D + CircleShape2D) as a child of each enemy scene. Wire it in `EnemyShip._ready()` via `@export`:

```gdscript
@export var detection_area: Area2D

func _ready() -> void:
    if detection_area:
        detection_area.body_entered.connect(_on_detection_body_entered)
        detection_area.body_exited.connect(_on_detection_body_exited)
    super()

func _on_detection_body_entered(body: Node) -> void:
    if body is PlayerShip:
        target = body
        transition(State.SEEKING)

func _on_detection_body_exited(body: Node) -> void:
    if body == target:
        target = null
        transition(State.IDLING)
```

Detection radius is set per enemy type in the inspector (CircleShape2D.radius). No shared constant needed.

Collision layer/mask to use: Layer 1 is "Ship" (confirmed from world.gd comment line 30). The detection Area2D should mask layer 1 only.

### 4. Simplified Fire — Timer + PackedScene Instantiation

Do NOT use `MountableWeapon`. Enemy fire is:

```gdscript
@export var bullet_scene: PackedScene
@export var fire_rate: float = 1.0
@export var bullet_speed: float = 800.0
@export var barrel: Node2D   # marker Node2D in scene

func _on_fire_timer_timeout() -> void:
    if not bullet_scene or not barrel or not target:
        return
    var b = bullet_scene.instantiate() as RigidBody2D
    b.global_position = barrel.global_position
    b.rotation = global_rotation
    b.apply_central_impulse(
        Vector2.from_angle(global_rotation) * bullet_speed
    )
    if "spawn_parent" in b:
        b.spawn_parent = spawn_parent
    if spawn_parent:
        spawn_parent.call_deferred("add_child", b)
    else:
        push_warning("EnemyShip %s: spawn_parent not set" % name)
```

`fire_timer.wait_time = fire_rate` is set in `_ready()` or when entering `FIGHTING` state. `fire_timer.start()` is called on state entry; `fire_timer.stop()` on state exit. The bullet scene can reuse existing `Bullet` (components/bullet.gd) with a `Damage` resource assigned — it already handles `body_entered` → `damage()`.

### 5. WaveManager — Dedicated Child of World Root

WaveManager is a new `Node` (not `Node2D`) added as a direct child of the world root in `world.tscn`. It is NOT inside `world.gd`'s script — it is a separate node with its own script `wave-manager.gd`.

Rationale: `world.gd` is already a developer test harness. Embedding wave logic there couples unrelated concerns and makes it harder to replace the harness later.

Scene tree position:

```
World (Node2D — world.gd)
  ├─ ShipBFG23
  ├─ Camera2D
  ├─ ShipCamera
  ├─ WaveManager    ← new Node, wave-manager.gd
  └─ ...asteroids...
```

WaveManager responsibilities:
- Hold `@export var spawn_parent: Node` (set to World in inspector)
- Hold wave definitions (Array of dicts or a WaveDefinition Resource)
- Instantiate enemy scenes, call `setup_spawn_parent` equivalent, add to `spawn_parent`
- Track living enemy count via `tree_exited` signal on each spawned enemy node

Integration with existing `setup_spawn_parent` pattern: `world.gd` currently has a local `setup_spawn_parent` function (lines 47–51). WaveManager must replicate this walk or call it. The cleanest approach is to move `setup_spawn_parent` to an autoload utility, or have WaveManager call `get_parent().setup_spawn_parent(enemy)` since world.gd is its parent. Do not inline duplicate logic.

### 6. spawn_parent Integration Points

`Body.die()` (body.gd lines 32–57) requires `spawn_parent` to be set on the dying node to place the death explosion scene. `Body.add_successor()` (lines 65–80) also requires it. `ItemDropper.drop()` (item-dropper.gd lines 7–23) requires it on the item node being spawned.

The propagation mechanism already exists: `Body._propagate_spawn_parent(node)` (body.gd lines 59–63) recursively sets `spawn_parent` on all children that have the property. This is called in `add_successor` (line 76) and in `MountPoint._slot_item_adding` (mount-point.gd line 108).

**Required integration:** WaveManager must call `_propagate_spawn_parent`-equivalent after instantiating each enemy. The simplest safe approach mirrors world.gd lines 47–51:

```gdscript
# In wave-manager.gd, after enemy = model.instantiate():
_setup_spawn_parent(enemy)
spawn_parent.add_child(enemy)

func _setup_spawn_parent(node: Node) -> void:
    if "spawn_parent" in node:
        node.spawn_parent = spawn_parent
    for child in node.get_children():
        _setup_spawn_parent(child)
```

### 7. Item Drop Integration

`Body.die()` calls `item_dropper.drop()` at line 55. This already works for any `Body` subclass. Enemy scenes need an `ItemDropper` node as a child (same pattern as existing ships/asteroids). No code changes needed — set `@export var item_dropper: ItemDropper` in the scene inspector. `ItemDropper.drop()` uses its own `spawn_parent` property; `_propagate_spawn_parent` will set it if the `ItemDropper` node has the property, which it does (item-dropper.gd line 4).

---

## Component Boundaries

| Component | File | New / Modified | Responsibility |
|-----------|------|---------------|----------------|
| EnemyShip | components/enemy-ship.gd | **Modified** | State enum, state machine scaffold, detection wiring, fire_timer, movement helpers |
| Beeliner | prefabs/beeliner/beeliner.gd | **New** | Override _tick_state for charge + fire behaviour |
| Flanker | prefabs/flanker/flanker.gd | **New** | Override _tick_state for orbit + engage behaviour |
| Sniper | prefabs/sniper/sniper.gd | **New** | Override _tick_state for standoff + flee behaviour |
| Swarmer | prefabs/swarmer/swarmer.gd | **New** | Override _tick_state for group charge behaviour |
| Suicider | prefabs/suicider/suicider.gd | **New** | Override _tick_state for ramming + die() on contact |
| WaveManager | world/wave-manager.gd (or similar) | **New** | Wave timing, enemy instantiation, spawn_parent setup |
| world.gd | world.gd | **Minor modification** | Add WaveManager child node; keep existing harness untouched |

---

## Build Order (Dependency-Respecting)

1. **EnemyShip base class** — all concrete types depend on it. Must compile before any prefab script is loaded.
2. **Detection Area wiring in EnemyShip** — required before any type that uses SEEKING/FLEEING states.
3. **Simplified fire logic in EnemyShip** — required before any type that uses FIGHTING state.
4. **Beeliner** — simplest type (SEEKING → FIGHTING only); validates base class and fire path end-to-end.
5. **Sniper** — introduces FLEEING; validates state reversal.
6. **Flanker** — introduces LURKING; validates multi-phase state sequence.
7. **Swarmer** — validates that N enemies can coexist without interference (no shared state).
8. **Suicider** — introduces contact-triggered `die()` override; validates that Body death pipeline still fires item drops.
9. **WaveManager** — depends on all enemy types being loadable as PackedScenes; build last.

---

## Data Flow: Enemy Combat Cycle

```
WaveManager.spawn_wave()
  → instantiate EnemyShip subclass
  → _setup_spawn_parent(enemy)
  → spawn_parent.add_child(enemy)
       ↓
EnemyShip._ready()
  → Ship._ready() → body_entered.connect + picker.body_entered.connect
  → detection_area.body_entered.connect
  → fire_timer created
       ↓
EnemyShip._physics_process()
  → _tick_state(delta)      ← overridden per type
       ├─ SEEKING: apply_force toward target.global_position
       ├─ FIGHTING: (fire_timer handles bullets)
       └─ FLEEING: apply_force away from target.global_position
       ↓
fire_timer.timeout → _on_fire_timer_timeout()
  → bullet_scene.instantiate()
  → spawn_parent.call_deferred("add_child", bullet)
       ↓
Bullet.collision(body)
  → body.damage(attack)      ← existing pipeline, no changes
       ↓
Body.die()
  → death scene instantiated  ← existing pipeline
  → item_dropper.drop()       ← existing pipeline
  → queue_free()
       ↓
WaveManager._on_enemy_tree_exited()
  → decrement living_count
  → if living_count == 0: start_next_wave()
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: State Machine in Per-Type Scripts Only
**What:** Defining the `State` enum in `beeliner.gd`, `flanker.gd` etc. separately.
**Why bad:** WaveManager and any future debug UI cannot query `enemy.current_state` without casting to a concrete type. Adding a new state requires editing every file.
**Instead:** Enum and `current_state` live in `EnemyShip`. Per-type scripts override virtual methods.

### Anti-Pattern 2: Reusing MountableWeapon for Enemy Fire
**What:** Giving enemies a weapon via the MountPoint/inventory system.
**Why bad:** Requires full inventory, slot signals, and drag-drop UI scaffolding. Couples enemy balancing to the player's weapon parameters. PROJECT.md explicitly calls this out as a decision (Key Decisions, row 7).
**Instead:** Inline timer + PackedScene instantiation in EnemyShip as described above.

### Anti-Pattern 3: Embedding WaveManager Logic in world.gd
**What:** Adding wave state and spawning loops inside `world.gd`.
**Why bad:** world.gd is an acknowledged test harness (PROJECT.md Context paragraph). It already has 167 lines of keyboard debug input. Adding wave logic bloats it and makes the harness unremovable.
**Instead:** Dedicated `WaveManager` node, separate script, exported `spawn_parent`.

### Anti-Pattern 4: Polling for Player Reference in _physics_process
**What:** Every enemy doing `get_tree().get_nodes_in_group("player")[0]` each frame.
**Why bad:** O(N) tree walk per enemy per physics frame. 10 enemies = 10 tree walks at 60Hz.
**Instead:** WaveManager injects `target` reference at spawn time: `enemy.target = player_ship_node`. Or EnemyShip caches via `detection_area.body_entered`.

### Anti-Pattern 5: Forgetting spawn_parent on Enemy Death Scenes
**What:** Enemy instantiated without `_propagate_spawn_parent` walk.
**Why bad:** `Body.die()` line 46 calls `spawn_parent.add_child(node)` where `spawn_parent` may be null, triggering the `push_warning` on line 48 and orphaning the explosion node (or crashing).
**Instead:** WaveManager always calls `_setup_spawn_parent(enemy)` before `spawn_parent.add_child(enemy)`.

---

## Integration Points with Existing Code (File + Line Level)

| Integration | File | Lines | What Changes |
|-------------|------|-------|-------------|
| EnemyShip builds on Ship._ready() | components/ship.gd | 16–19 | Call `super()` in EnemyShip._ready() — already expected by Ship |
| EnemyShip inherits damage pipeline | components/body.gd | 19–30 | No change — `damage()` and `die()` work on any Body subclass |
| spawn_parent propagation | components/body.gd | 59–63 | WaveManager replicates this walk for enemies it spawns |
| item_dropper called in die() | components/body.gd | 55 | No change — EnemyShip scenes need an ItemDropper child node configured in inspector |
| Bullet reuse for enemy projectiles | components/bullet.gd | 1–19 | No change — assign a Damage resource in the scene, it already calls body.damage() |
| Ship._on_body_entered kinetic damage | components/ship.gd | 37–41 | No change — PlayerShip takes kinetic damage from enemy collisions automatically |
| Ship.picker_body_entered item pickup | components/ship.gd | 43–58 | No change — enemies do NOT need picker (set can_pick_coin = false; omit picker Area2D or leave disconnected) |
| world.gd setup_spawn_parent | world.gd | 47–51 | WaveManager calls same logic; consider extracting to shared utility in later cleanup |
| world.gd _ready() | world.gd | 39–45 | Add `$WaveManager.player = $ShipBFG23` after existing setup lines |
| MountableBody.Action enum | components/mountable-body.gd | 4–11 | No change needed — enemies do not use do()/mount_weapon() unless they have weapons via MountPoint |

---

## Scalability Notes

| Concern | At 5 enemies | At 50 enemies | Mitigation |
|---------|-------------|--------------|------------|
| Physics process overhead | Negligible | Moderate | State machine avoids per-frame target lookups; apply_force is O(1) per body |
| Detection area overlap events | Fine | Fine | Signal-driven, not polled |
| Bullet instantiation | Fine | Moderate | Reuse Bullet class; consider object pooling at v3.0 |
| WaveManager enemy tracking | Fine | Fine | Single Array counter; tree_exited signal is O(1) |

---

## Sources

All findings derived from direct source inspection:
- `components/body.gd` — health/death/spawn_parent pipeline
- `components/mountable-body.gd` — Action enum, do() routing
- `components/ship.gd` — Ship._ready(), picker, inventory
- `components/enemy-ship.gd` — confirmed stub (2 lines only)
- `components/player-ship.gd` — confirmed stub (1 line only)
- `components/propeller-movement.gd` — movement pattern to replicate
- `components/mountable-weapon.gd` — fire pattern to simplify
- `components/bullet.gd` — reusable projectile
- `components/item-dropper.gd` — drop pipeline, spawn_parent usage
- `components/mount-point.gd` — plug/unplug, spawn_parent
- `components/explosion.gd` — death scene pattern
- `world.gd` — setup_spawn_parent, spawn pattern, scene tree layout
- `prefabs/ship-bfg-23/ship-bfg-23.tscn` — confirmed node structure for reference
- `.planning/PROJECT.md` — confirmed scope, key decisions, constraints
