# Phase 4: EnemyShip Infrastructure - Research

**Researched:** 2026-04-11
**Domain:** GDScript state machines, RigidBody2D steering, Area2D detection, Godot 4 scene inheritance
**Confidence:** HIGH (all core patterns verified against codebase + community sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Add a null guard (`if picker:`) before `picker.body_entered.connect(...)` in `Ship._ready()`.
**D-02:** EnemyShip scenes have no picker `Area2D` node.
**D-03:** Phase 4 delivers both `enemy-ship.gd` and `base-enemy-ship.tscn` skeleton scene.
**D-04:** Base scene skeleton: root EnemyShip + `CollisionShape2D` + `Sprite2D` placeholder + `Area2D` detection node + barrel `Node2D` + `ItemDropper`. No picker.
**D-05:** Concrete types (Phase 5+) inherit `base-enemy-ship.tscn` and override sprite, collision shape, and `@export` values.
**D-06:** EnemyShip base class has NO fire loop infrastructure. Fire logic is entirely in concrete types.
**D-07:** Phase 4 establishes fire pattern as convention only (`spawn_parent.add_child()` at barrel position). ENM-05 validated at Phase 5.
**D-08:** Barrel `Node2D` included in base scene for consistent reference — base class script does not use it.
**D-09:** `State` enum with 8 values: IDLING, SEEKING, LURKING, FIGHTING, FLEEING, PATROLLING, EVADING, ESCORTING + `current_state: State` variable.
**D-10:** Three virtual methods — `_tick_state(delta)`, `_enter_state(new_state)`, `_exit_state(old_state)` — empty defaults in base class.
**D-11:** State transitions via `_change_state(new_state: State)` helper: `_exit_state` → `current_state =` → `_enter_state`.
**D-12:** All calls to `_tick_state` and fire logic guarded by `if dying: return`.
**D-13:** Detection uses `Area2D` in base scene; `@onready var detection_area: Area2D = $DetectionArea`.
**D-14:** Layer/mask bits set explicitly with inline comment referencing `world.gd` physics layer table.
**D-15:** `body_entered` on detection area drives IDLING → SEEKING in base class.
**D-16:** `apply_central_force()` for steering; max speed clamped via `linear_velocity = linear_velocity.limit_length(max_speed)` in `_integrate_forces`. No direct `linear_velocity` assignment.
**D-17:** `@export var max_speed: float` and `@export var thrust: float` on base class.
**D-18:** State transitions emit a `print()` log during Phase 4 development.

### Claude's Discretion

- Exact `CollisionShape2D` shape (circle placeholder is fine)
- `Sprite2D` placeholder texture (blank or 1x1 white pixel)
- Whether `_tick_state` is called from `_process` or `_physics_process` (`_physics_process` preferred)
- `ItemDropper` configuration in base scene (leave exports unset)

### Deferred Ideas (OUT OF SCOPE)

- Fire loop infrastructure in EnemyShip base class
- Flocking / Boids cohesion for Swarmer
- Predictive targeting for Sniper
- Pre-wave HUD announcement
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENM-01 | EnemyShip base class defines `State` enum (8 states) and virtual `_tick_state`, `_enter_state`, `_exit_state` methods | State machine section: enum+match pattern confirmed |
| ENM-02 | All state ticks and fire calls guarded by `dying` flag | Dying guard section: `Body.dying` field confirmed, guard placement pattern documented |
| ENM-03 | Movement uses `apply_central_force`; max speed clamped in `_integrate_forces` via `limit_length` | Steering section: pattern confirmed, jitter pitfall documented |
| ENM-04 | Detection via `Area2D` with explicit layer/mask bits documented in code comments | Detection section: layer/mask wiring pattern confirmed via explosion.gd and ship-bfg-23.tscn |
| ENM-05 | Fire uses `spawn_parent.add_child()` at barrel `Node2D` — convention established, not enforced in base | Convention pattern section: `spawn_parent` propagation verified in body.gd |
| ENM-06 | Enemy projectiles carry fixed energy `Damage` resource per enemy type | Damage section: existing Bullet+Damage pattern confirmed, no new infrastructure needed |
| ENM-15 | All enemy scenes omit picker `Area2D` | Null guard section: `Ship._ready()` fix documented |
</phase_requirements>

---

## Summary

Phase 4 builds the `EnemyShip` base class and `base-enemy-ship.tscn` skeleton on top of an existing, well-structured class hierarchy (`Body → MountableBody → Ship → EnemyShip`). All the infrastructure this phase needs already exists in the codebase — the `dying` flag, `spawn_parent` propagation, `apply_central_force` precedent (via `PropellerMovement`), and `Area2D` wiring patterns (via `Explosion` and `ship-bfg-23.tscn`). No new patterns need to be invented.

The primary implementation challenge is the steering-plus-speed-clamp pattern for `RigidBody2D`: applying a force each physics frame while clamping max speed without creating jitter. The correct solution (`_integrate_forces` with `state.linear_velocity = state.linear_velocity.limit_length(max_speed)`) is well-established in the Godot community and confirmed by the codebase's own `PropellerMovement` pattern which uses `apply_force`.

The second challenge is correct `Area2D` layer/mask wiring. The `Explosion` component in the codebase already demonstrates the exact `set_collision_layer_value` / `set_collision_mask_value` API (Godot 4 style), and the physics layer table in `world.gd` provides the authoritative bit numbers (Ship=1).

**Primary recommendation:** Use enum+match inline state machine (not class-per-state nodes), `_physics_process` for state ticking, `_integrate_forces` for speed clamping, and mirror `explosion.gd`'s Area2D layer/mask API exactly.

---

## Standard Stack

### Core (all native Godot 4.6.2, no external packages)

| Component | Godot API | Purpose | Why Standard |
|-----------|-----------|---------|--------------|
| State machine | `enum State` + `match current_state` in `_physics_process` | AI behavior dispatch | Idiomatic GDScript; no plugin needed |
| Steering force | `apply_central_force(vector)` on `RigidBody2D` | Continuous acceleration toward target | Consistent with existing `PropellerMovement.apply_force` pattern |
| Speed clamp | `_integrate_forces(state)` + `state.linear_velocity.limit_length(max_speed)` | Prevent jitter-free max speed | Only safe way to clamp `RigidBody2D` velocity |
| Detection | `Area2D` + `body_entered` signal | Player detection radius | Same pattern as `Picker` in `ship-bfg-23.tscn` and `Explosion` |
| Bullet spawning | `spawn_parent.add_child(bullet)` | Scene-tree-safe instantiation | Already used by `Body.die()` for explosion/successor nodes |
| Damage resource | `Damage` resource with `energy` field | Fixed per-type projectile damage | Existing `Bullet.attack: Damage` pattern — no new system needed |

### No Installation Required

All components are native Godot 4 APIs. No `npm install`, no plugins, no GDNative. Engine version confirmed: Godot 4.6.2 (per Phase 3 migration).

---

## Architecture Patterns

### Recommended Project Structure

```
components/
├── enemy-ship.gd          # Base class — this phase builds this out
├── body.gd                # Already exists — provides dying, spawn_parent
├── ship.gd                # Already exists — needs null guard on picker
prefabs/
├── enemies/
│   └── base-enemy-ship.tscn    # Skeleton scene — this phase creates
```

Note: The `prefabs/enemies/` directory does not yet exist. Create it. Concrete types in Phases 5-9 will add their own subdirectories under `prefabs/enemies/`.

### Pattern 1: Enum + Match Inline State Machine (Godot 4 GDScript)

**What:** Single script, `State` enum, `match current_state` inside `_physics_process`.
**When to use:** When states are behaviors of a single node (not separate scene nodes). This is the right choice for EnemyShip — states are behavioral modes, not independent objects.
**Why not class-per-state nodes:** GDQuest's node-based pattern is powerful but adds 8 scene nodes per enemy and indirection overhead. For this codebase's pattern of direct GDScript inheritance, the inline enum approach is simpler and sufficient.

```gdscript
# Source: established Godot 4 GDScript community pattern [CITED: shaggydev.com/2023/10/08/godot-4-state-machines/]
class_name EnemyShip
extends Ship

enum State {
    IDLING,
    SEEKING,
    LURKING,
    FIGHTING,
    FLEEING,
    PATROLLING,
    EVADING,
    ESCORTING
}

var current_state: State = State.IDLING

func _physics_process(delta: float) -> void:
    if dying:
        return
    _tick_state(delta)

func _tick_state(_delta: float) -> void:
    pass  # override in concrete types

func _enter_state(_new_state: State) -> void:
    pass  # override in concrete types

func _exit_state(_old_state: State) -> void:
    pass  # override in concrete types

func _change_state(new_state: State) -> void:
    _exit_state(current_state)
    var old = current_state
    current_state = new_state
    _enter_state(new_state)
    print("[EnemyShip] state: %s → %s" % [State.keys()[old], State.keys()[new_state]])
```

### Pattern 2: RigidBody2D Steering with Force + _integrate_forces Clamp

**What:** Apply a steering force in `_physics_process`; clamp speed in `_integrate_forces`.
**Why two methods:** `apply_central_force` accumulates over physics frames; `_integrate_forces` runs after forces are integrated and is the only place to safely write `state.linear_velocity` without breaking the physics simulation. Direct `linear_velocity =` assignment outside of `_integrate_forces` is explicitly warned against in Godot docs.
**Jitter warning:** Do NOT use `set_constant_force` and then clamp the result — this causes opposing-action jitter. Apply force conditionally OR clamp only in `_integrate_forces`.

```gdscript
# Source: kidscancode.org/godot_recipes/4.x/kyn/rigidbody2d/ [CITED] + Godot forum [CITED: forum.godotengine.org/t/clamp-top-speed-giving-a-jittery-look/40420]
@export var max_speed: float = 500.0
@export var thrust: float = 200.0

func _physics_process(delta: float) -> void:
    if dying:
        return
    _tick_state(delta)

func steer_toward(target_position: Vector2) -> void:
    var direction = (target_position - global_position).normalized()
    apply_central_force(direction * thrust)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    state.linear_velocity = state.linear_velocity.limit_length(max_speed)
```

**Critical:** `_integrate_forces` receives a `PhysicsDirectBodyState2D` parameter. The velocity is clamped via `state.linear_velocity`, NOT `linear_velocity` directly. [VERIFIED: Godot forum threads confirm `state.linear_velocity` is the correct property inside `_integrate_forces`]

### Pattern 3: Area2D Detection (Godot 4 API)

**What:** `Area2D` with explicit layer/mask bits wired to detect Ship-layer bodies.
**Key rule:** The Area2D's `collision_mask` must include the physics layer that the target RigidBody2D is on. The Area2D's `collision_layer` is what OTHER things sense; the `collision_mask` is what IT senses.
**Physics layer for ships:** Layer 1 (confirmed in `world.gd` lines 28-36).

```gdscript
# Source: explosion.gd pattern [VERIFIED: components/explosion.gd lines 35-39] + world.gd layer table [VERIFIED]
# Physics layers (world.gd):
# 1=Ship  2=Weapons  3=Bullets  4=Asteroids  5=Explosions  6=Coins  7=Ammo  8=WeaponItem

@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
    super()
    # Detection area: detect Ship layer (1) only
    # Set layer to 0 (the detection area does not need to BE on any layer)
    # Set mask bit 1 = true to detect ships
    detection_area.set_collision_layer_value(1, false)  # area is not on layer 1
    detection_area.set_collision_mask_value(1, true)    # area detects layer 1 (Ship)
    detection_area.body_entered.connect(_on_detection_area_body_entered)

func _on_detection_area_body_entered(body: Node2D) -> void:
    if body is PlayerShip:
        if current_state == State.IDLING:
            _change_state(State.SEEKING)
```

**Important:** The `set_collision_layer_value(bit, bool)` and `set_collision_mask_value(bit, bool)` API is the Godot 4 way. Godot 3 used `set_collision_layer_bit`. [VERIFIED: explosion.gd uses this API correctly at lines 35-39]

### Pattern 4: Dying Guard

**What:** Guard at the top of `_physics_process` and any fire-related calls.
**Where `dying` lives:** `Body.dying` (confirmed in `components/body.gd` line 14 — `var dying = false`). Set to `true` in `Body.die()` line 39. EnemyShip inherits this directly.

```gdscript
# Source: components/body.gd [VERIFIED: line 14, 39]
func _physics_process(delta: float) -> void:
    if dying:
        return
    _tick_state(delta)

# Fire guard (in concrete types — documented here as required convention):
func _fire() -> void:
    if dying:
        return
    # ... instantiate bullet
```

**Why not a DEAD state:** Using `dying` directly avoids adding a DEAD state to the enum that would never transition away. The `die()` method already calls `queue_free()` after the delay — state machine cleanup is unnecessary.

### Pattern 5: spawn_parent.add_child() for Enemy Bullets

**What:** Bullets are added to `spawn_parent` (the world root node), not `get_tree().current_scene`.
**Why:** `spawn_parent` is explicitly propagated to all children by `world.gd`'s `setup_spawn_parent()` and `Body._propagate_spawn_parent()`. This ensures bullets are world-children, not children of the enemy (which would move with the enemy).

```gdscript
# Source: components/body.gd lines 59-63 [VERIFIED], world.gd lines 47-50 [VERIFIED]
# In concrete enemy type (not base class — D-06):
func _fire() -> void:
    if dying:
        return
    var bullet = bullet_scene.instantiate()
    bullet.global_position = $Barrel.global_position
    bullet.rotation = global_rotation
    bullet.attack = attack_damage  # Damage resource — fixed per type (ENM-06)
    if spawn_parent:
        spawn_parent.add_child(bullet)
    else:
        push_warning("EnemyShip: spawn_parent not set on " + name)
```

### Pattern 6: Godot Scene Inheritance for Enemy Types

**What:** Concrete enemy scenes use Godot's "New Inherited Scene" from `base-enemy-ship.tscn`.
**How it works in .tscn files:** An inherited scene stores only the `[gd_scene]` header with `load_steps` and `uid`, plus override nodes. The inherited base is referenced via `[ext_resource]` and the root node carries `instance=ExtResource(...)`.
**Editor workflow:** Right-click `base-enemy-ship.tscn` in FileSystem → "New Inherited Scene". The resulting `.tscn` can override sprite texture, collision shape, and `@export` values without duplicating the full scene.
**Script override:** Concrete types add a new `.gd` file that `extends EnemyShip` and attach it as the root node's script override in the inherited scene.

[CITED: godot docs / community — inherited scenes store only deltas from parent]

### Anti-Patterns to Avoid

- **Direct `linear_velocity` assignment outside `_integrate_forces`:** Breaks physics simulation. Use `_integrate_forces` for velocity modification.
- **`get_tree().current_scene.add_child(bullet)`:** Fragile — fails during scene transitions (even if this game has no transitions, the pattern is explicitly wrong per codebase convention). Always use `spawn_parent.add_child()`.
- **Class-per-state node pattern for this codebase:** Over-engineering for 8 simple behavioral modes. Inline enum+match is idiomatic and sufficient.
- **Setting `collision_mask` as a bitmask integer directly (e.g., `collision_mask = 1`):** Works but is not maintainable. Use `set_collision_mask_value(bit, bool)` with a comment matching `world.gd`'s layer table.
- **Connecting `detection_area.body_entered` before `super()` in `_ready()`:** `super()` must be called first (Ship._ready calls body_entered.connect on the ship itself). Call `super()` first, then connect the detection area.
- **`MountableBody._physics_process` conflict:** `MountableBody` already implements `_physics_process` for mount sync. EnemyShip's `_physics_process` must call `super()` to preserve mount syncing — or since enemies won't have mounts, verify whether `super()` is needed. [ASSUMED — see Assumptions Log A1]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Speed limiting for RigidBody2D | Custom force-feedback loop | `state.linear_velocity.limit_length(max_speed)` in `_integrate_forces` | Godot provides this; custom solutions cause jitter |
| State machine framework | Node-per-state plugin/library | `enum State` + `match` in GDScript | LimboAI is out of scope; inline enum is idiomatic |
| Damage on bullet hit | Custom collision/health system | Existing `Bullet` + `Damage` + `Body.damage()` pipeline | Already handles energy, kinetic, defense calculation |
| Bullet world parenting | `add_child_below_node`, `get_tree().current_scene` | `spawn_parent.add_child()` | Already propagated by `world.gd`'s setup |
| Detection radius query | Manual `get_overlapping_bodies()` polling | `Area2D.body_entered` signal | Signal is event-driven, lower overhead than per-frame polling |

**Key insight:** The codebase already has every primitive this phase needs. The task is wiring them together correctly, not building new systems.

---

## Common Pitfalls

### Pitfall 1: Jitter from Force + Direct Velocity Clamp

**What goes wrong:** Developer applies `apply_central_force(direction * thrust)` every frame AND directly assigns `linear_velocity = linear_velocity.limit_length(max_speed)` in `_physics_process`. The physics engine fights itself — each frame: force accelerates, then velocity is brutally cut. Result: visible jitter especially at top speed.

**Why it happens:** `linear_velocity` outside `_integrate_forces` is a read-only-in-spirit property that the physics engine re-calculates. Writing to it mid-frame doesn't prevent the already-queued force from being applied.

**How to avoid:** ONLY modify `linear_velocity` inside `_integrate_forces` via the `state` parameter: `state.linear_velocity = state.linear_velocity.limit_length(max_speed)`.

**Warning signs:** Enemy ship shudders or bounces at top speed. Velocity oscillates above and below `max_speed` in debug prints.

### Pitfall 2: Area2D body_entered Not Firing

**What goes wrong:** `DetectionArea` exists in the scene but `body_entered` never fires when the player ship enters it.

**Why it happens:** Either (a) `detection_area.collision_mask` doesn't include layer 1 (Ship), or (b) the player ship's `collision_layer` doesn't include layer 1. Looking at `ship-bfg-23.tscn`: the root node has `collision_mask = 12` (bits 3+4 = Bullets+Asteroids) but the ship's own `collision_layer` is not explicitly set — Godot defaults to layer 1 for RigidBody2D. Confirm this.

**How to avoid:** Explicitly call `detection_area.set_collision_mask_value(1, true)` in `_ready()`. Add a comment: `# Layer 1 = Ship (world.gd line 29)`. Test by printing from `_on_detection_area_body_entered` immediately.

**Warning signs:** No print output when player enters the visual detection radius during testing.

### Pitfall 3: MountableBody._physics_process Not Called (or Double-Called)

**What goes wrong:** `EnemyShip._physics_process(delta)` overrides without `super(delta)`, breaking `MountableBody`'s mount sync loop. Or: calling `super()` when enemies have no mounts causes a silent no-op (harmless) vs. an error if mounts list is unexpectedly populated.

**Why it happens:** GDScript method override replaces the parent method unless `super()` is explicitly called.

**How to avoid:** Since enemies won't have mount points, calling `super()` in `_physics_process` is a no-op but safe. Include it for correctness: `super(delta)` at the start. If performance profiling later shows it's overhead, remove it then.

**Warning signs:** If a mounted weapon were somehow added to an enemy, it would not track position — visual glitch.

### Pitfall 4: picker.body_entered Crash Without Null Guard

**What goes wrong:** `Ship._ready()` calls `picker.body_entered.connect(picker_body_entered)` unconditionally. An EnemyShip scene (which has no Picker node) will throw a null reference error at startup.

**Why it happens:** `picker: Area2D` is an `@export` that defaults to `null` if not assigned in the scene. Current `Ship._ready()` (line 18) has no null check.

**How to avoid:** Add `if picker:` guard before the connect call. This is D-01 and must be applied to `ship.gd` in this phase.

**Warning signs:** The game crashes with "Invalid get index 'body_entered' on base 'Nil'" when placing the base enemy scene in world.tscn.

### Pitfall 5: spawn_parent Not Set on Enemy

**What goes wrong:** Enemy is instantiated and added to the scene but `spawn_parent` is `null`. Bullet instantiation calls `spawn_parent.add_child(bullet)` and crashes. Also `Body.die()` will warn and not spawn death effects.

**Why it happens:** `world.gd`'s `setup_spawn_parent()` must be explicitly called after adding the enemy to the scene. It is not automatic on `_ready()`.

**How to avoid:** In Phase 4's world.gd test placement, call `setup_spawn_parent(enemy_instance)` immediately after `add_child(enemy_instance)`. Document this as a required setup step for Phase 5's WaveManager.

**Warning signs:** `push_warning("spawn_parent not set on ...")` appears in the output console.

### Pitfall 6: State Machine Transition During Dying

**What goes wrong:** An `Area2D.body_entered` signal fires during the death delay (after `die()` is called but before `queue_free()`). The `_on_detection_area_body_entered` handler calls `_change_state(State.SEEKING)` on a dying enemy.

**Why it happens:** Signals are not automatically disconnected when `dying` is set. The detection area is still monitoring after death starts.

**How to avoid:** The `if dying: return` guard in `_physics_process` handles the `_tick_state` path. The signal handler `_on_detection_area_body_entered` also needs the guard: `if dying: return`. Add it there too.

**Warning signs:** Enemy transitions to SEEKING after health reaches 0.

---

## Code Examples

Verified patterns directly from the codebase or Godot 4 official APIs:

### explosion.gd Area2D setup (reference implementation)
```gdscript
# Source: components/explosion.gd lines 35-39 [VERIFIED]
area.set_collision_layer_value(5, true)
area.set_collision_mask_value(1, false)
area.set_collision_mask_value(2, false)
area.set_collision_mask_value(3, false)
area.set_collision_mask_value(4, true)
```
The detection area in EnemyShip should mirror this exact API.

### Body.die() + spawn_parent.add_child() (reference)
```gdscript
# Source: components/body.gd lines 44-48 [VERIFIED]
if spawn_parent:
    spawn_parent.add_child(node)
else:
    push_warning("spawn_parent not set on " + name)
```
Enemy bullet spawning must follow this exact pattern including the warning.

### PropellerMovement.apply_force (steering precedent)
```gdscript
# Source: components/propeller-movement.gd lines 20-24 [VERIFIED]
body.apply_force(
    profile.vector.rotated(body.rotation) * profile.thrust * delta * 100,
    position.rotated(body.rotation)
)
```
Enemy steering should use `apply_central_force` (simpler — no offset position needed). The force-per-frame pattern is established.

### Ship._ready() null guard location
```gdscript
# Source: components/ship.gd lines 16-19 [VERIFIED]
func _ready():
    body_entered.connect(_on_body_entered)
    picker.body_entered.connect(picker_body_entered)  # <-- line 18: needs null guard
    super()
```
Change line 18 to: `if picker: picker.body_entered.connect(picker_body_entered)`

### _integrate_forces velocity clamp (Godot 4 pattern)
```gdscript
# Source: Godot 4 community pattern [CITED: forum.godotengine.org/t/clamp-top-speed-giving-a-jittery-look/40420]
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    state.linear_velocity = state.linear_velocity.limit_length(max_speed)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `set_collision_layer_bit(n, val)` | `set_collision_layer_value(n, val)` | Godot 4.0 | API rename — `_bit` → `_value` suffix |
| `linear_velocity.clamped(max_speed)` | `linear_velocity.limit_length(max_speed)` | Godot 4.2+ | Method rename — `clamped` → `limit_length` on Vector2 |
| `Physics2DDirectBodyState` | `PhysicsDirectBodyState2D` | Godot 4.0 | Class renamed |
| Direct `linear_velocity` assign | `_integrate_forces` + `state.linear_velocity` | Godot 4 docs warning | Safety — direct assign outside integrate_forces breaks physics |

**Deprecated/outdated:**
- `set_collision_layer_bit()`: Renamed to `set_collision_layer_value()` in Godot 4.0. Using the old name will cause a GDScript error.
- `linear_velocity.clamped()`: Renamed to `.limit_length()` in Godot 4.2. Project is on 4.6.2.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `MountableBody._physics_process` should be called via `super()` from `EnemyShip._physics_process` | Architecture Patterns, Pitfall 3 | If enemies never have mounts, `super()` is a no-op. Low risk. |
| A2 | Player ship (`ShipBFG23`) is on physics layer 1 by default (Godot RigidBody2D default) | Detection section | If layer is 0 or other, detection won't fire. Verify in editor or check `ship-bfg-23.tscn` — collision_mask is set to 12 but collision_layer is not explicitly set (Godot default = 1). |

---

## Open Questions (RESOLVED)

1. **Does ShipBFG23 have an explicit collision_layer set?**
   - RESOLVED: Godot default `collision_layer` for `RigidBody2D` is 1 (bit 1 set). Since `ship-bfg-23.tscn` has no explicit `collision_layer` line, it uses the Godot default. This matches `world.gd` layer 1 = Ship. Detection `Area2D` with `collision_mask` bit 1 will correctly detect the player ship.

2. **Should `_tick_state` be called from `_process` or `_physics_process`?**
   - RESOLVED: `_physics_process` — per CONTEXT.md discretion (which prefers `_physics_process`) and plan 04-01 implementation. Keeps all physics behavior (state ticking, steering force application) in one callback, avoids split-frame issues. Consistent with `MountableBody._physics_process` for mount sync.

---

## Environment Availability

Step 2.6: SKIPPED — This phase is code-only changes (GDScript + .tscn files). No external CLI tools, services, or runtimes beyond the Godot 4.6.2 editor required. Godot 4.6.2 was confirmed installed in Phase 3.

---

## Sources

### Primary (HIGH confidence)
- `components/body.gd` [VERIFIED] — `dying` flag, `spawn_parent`, `_propagate_spawn_parent`, `die()`
- `components/ship.gd` [VERIFIED] — `picker: Area2D`, `_ready()` connection needing null guard
- `components/mountable-body.gd` [VERIFIED] — `_physics_process` mount sync, `Action` enum pattern
- `components/explosion.gd` [VERIFIED] — `set_collision_layer_value` / `set_collision_mask_value` API usage
- `components/propeller-movement.gd` [VERIFIED] — `apply_force` per physics frame pattern
- `prefabs/ship-bfg-23/ship-bfg-23.tscn` [VERIFIED] — physics layer/mask values, Picker Area2D structure
- `world.gd` lines 28-36 [VERIFIED] — Physics layer table: Ship=1, Weapons=2, Bullets=3, Asteroids=4, Explosions=5, Coins=6, Ammo=7, WeaponItem=8

### Secondary (MEDIUM confidence)
- [CITED: shaggydev.com/2023/10/08/godot-4-state-machines/] — enum+match state machine pattern for Godot 4
- [CITED: kidscancode.org/godot_recipes/4.x/kyn/rigidbody2d/] — RigidBody2D `_integrate_forces` best practices
- [CITED: forum.godotengine.org/t/clamp-top-speed-giving-a-jittery-look/40420] — force+clamp jitter cause and fix
- [CITED: godotforums.org/d/36226-detecting-collisions-between-rigidbody2d-and-area2d] — Area2D layer/mask must match target RigidBody2D layer

### Tertiary (LOW confidence)
- None — all critical claims are verified against the codebase or cited official patterns.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Godot 4 native APIs, verified against existing codebase usage
- Architecture: HIGH — state machine and steering patterns verified; scene inheritance confirmed
- Pitfalls: HIGH — jitter pitfall confirmed by forum sources, null crash confirmed by reading ship.gd directly

**Research date:** 2026-04-11
**Valid until:** 2026-06-01 (Godot 4 GDScript APIs are stable; these patterns won't change)
