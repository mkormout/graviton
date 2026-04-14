# Phase 8: Swarmer - Research

**Researched:** 2026-04-13
**Domain:** Godot 4 GDScript — swarming AI, Area2D cohesion detection, force application patterns
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Swarmer fires weak bullets while in FIGHTING state — Timer-based fire pattern, same as Beeliner/Flanker. Low `Damage.energy`.
- **D-02:** New `swarmer-bullet.tscn` at `prefabs/enemies/swarmer/swarmer-bullet.tscn` — structural copy of `beeliner-bullet.tscn`. Sprite2D blank.
- **D-03:** Bullet spawning: `spawn_parent.add_child(bullet)` at `$Barrel.global_position`. Fixed `Damage.energy` resource.
- **D-04:** `_angle_offset: float` in `_ready()` from `deg_to_rad(randf_range(-40.0, 40.0))`. Applied to SEEKING steering direction.
- **D-05:** Angular offset is constant per-instance (baked in `_ready()`).
- **D-06:** CohesionArea (Area2D) with configurable `cohesion_radius`. Mask: Ship layer (1). Filter by `body is Swarmer` in signal handler.
- **D-07:** When nearby swarmers present: (1) multiply steering force by `cohesion_thrust_scale` (~0.3), (2) apply separation push per nearby Swarmer.
- **D-08:** Cohesion active in all states (SEEKING and FIGHTING).
- **D-09:** No WaveManager changes. Cluster = count 4–6 in existing wave entry.
- **D-10:** States: IDLING → SEEKING → FIGHTING → SEEKING or IDLING.
- **D-11:** SEEKING → FIGHTING when player within `fight_range`. Start fire timer.
- **D-12:** FIGHTING → SEEKING when player leaves `fight_range` (with hysteresis).
- **D-13:** No FLEEING, no LURKING, no EVADING.
- **D-14:** `swarmer.tscn` inherits `base-enemy-ship.tscn`. Structural additions: FireTimer (Timer) + CohesionArea (Area2D + CollisionShape2D). No picker Area2D.
- **D-15:** Low HP (lower than Beeliner's 30).
- **D-16:** Loot: coins + ammo.
- **D-17:** `die()` override: stop fire timer, call `_ammo_dropper.drop()`, then `super(delay)`.

### Claude's Discretion
- Exact `fight_range` value
- Exact `cohesion_radius` (slightly larger than collision shape radius * 2)
- Exact `cohesion_thrust_scale` (suggested ~0.3)
- Exact `separation_force` magnitude
- Fire timer interval (faster/lighter than Beeliner)
- Exact bullet speed and `Damage.energy` (noticeably lower than Beeliner)
- Swarmer base HP value (lower than Beeliner's 30)
- Per-instance variation: `thrust *= randf_range(0.8, 1.2)`, `max_speed *= randf_range(0.8, 1.2)`

### Deferred Ideas (OUT OF SCOPE)
- Swarmer sprite — placeholder `_draw()` only for this phase
- Full Boids alignment + cohesion — explicitly out of scope per REQUIREMENTS.md
- Group attack coordination — deferred to v2.1+
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENM-10 | Swarmer — low HP, cluster-spawned, reduces thrust when near group members (proximity cohesion without full Boids); no picker node in scene | Area2D body_entered/exited for cohesion tracking; `apply_central_force` with per-frame scale; angle offset in `_ready()` for multi-vector approach; Timer fire loop identical to Beeliner |
</phase_requirements>

---

## Summary

The Swarmer is the fourth concrete enemy type, extending the established `EnemyShip` → `Ship` → `Body` hierarchy. All fundamental patterns are already proven by Beeliner and Flanker: Timer-based fire loops, `_change_state()` transitions, `@export` tuning vars, `steer_toward()` for approach, per-instance variation in `_ready()`, and the `die()` override chain. The Swarmer adds two new mechanisms on top of this foundation: (1) a per-instance angle offset applied during SEEKING to spread the cluster across multiple approach vectors, and (2) an `Area2D`-based cohesion system that reduces thrust and pushes separation when Swarmers are proximate.

The cohesion system is the only genuinely novel piece. Research confirms that `Area2D.body_entered/body_exited` signals are reliable for maintaining a live `_nearby_swarmers` array, but require an `is_instance_valid()` guard in the force-application tick to handle Swarmers that die mid-frame before their `body_exited` fires. Separation force should use linear distance falloff (not inverse-square) to avoid jitter at close range. All cohesion forces are applied via `apply_central_force` in `_physics_process`, consistent with ENM-03.

The bullet scene structure is confirmed by reading the codebase: `beeliner-bullet.tscn` uses `RigidBody2D` with `EnemyBullet` script, embedded Damage sub_resource, `RectangleShape2D` collision, and `collision_layer = 256` (Layer 9 — the established enemy bullet layer). The CONTEXT.md comment about "layer 3 (Bullets)" for the swarmer bullet is a documentation error; the actual layer to use is 9 (integer value 256), matching all other enemy bullets.

**Primary recommendation:** Follow Flanker as the primary structural template (range-based SEEKING↔FIGHTING transitions with hysteresis), follow Beeliner for the fire loop pattern, and add cohesion as a physics property computed per-frame in `_physics_process` using the `_nearby_swarmers` array maintained by CohesionArea signals.

---

## Architecture Patterns

### Recommended File Structure

```
components/
└── swarmer.gd                           # New — Swarmer concrete enemy class

prefabs/enemies/swarmer/
├── swarmer.tscn                         # New — inherits base-enemy-ship.tscn
└── swarmer-bullet.tscn                  # New — copy of beeliner-bullet.tscn structure
```

### Pattern 1: Class Declaration and Exports

Follow the exact Flanker pattern for class declaration and export organization.
[VERIFIED: components/flanker.gd read directly]

```gdscript
class_name Swarmer
extends EnemyShip

# --- Tuning exports ---
@export var fight_range: float = 5000.0
@export var cohesion_radius: float = 700.0
@export var cohesion_thrust_scale: float = 0.3
@export var separation_force: float = 800.0
@export var bullet_speed: float = 3500.0

# --- Instance state ---
var _target: Node2D = null
var _angle_offset: float = 0.0
var _nearby_swarmers: Array[EnemyShip] = []

var _bullet_scene := preload("res://prefabs/enemies/swarmer/swarmer-bullet.tscn")

@onready var _fire_timer: Timer = $FireTimer
@onready var _ammo_dropper: ItemDropper = $AmmoDropper
@onready var _barrel: Node2D = $Barrel
@onready var _cohesion_area: Area2D = $CohesionArea
```

### Pattern 2: _ready() Initialization

Per-instance randomization is the established pattern. [VERIFIED: components/flanker.gd, components/beeliner.gd]

```gdscript
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    _angle_offset = deg_to_rad(randf_range(-40.0, 40.0))

    # CohesionArea layer/mask — Ship layer only (world.gd: 1=Ship)
    # collision_layer = 0: area has no layer of its own (does not block anything)
    # collision_mask = 1: detects bodies on Layer 1 (Ship) — Swarmers are on layer 1
    _cohesion_area.collision_layer = 0
    _cohesion_area.collision_mask = 1
    _cohesion_area.body_entered.connect(_on_cohesion_area_body_entered)
    _cohesion_area.body_exited.connect(_on_cohesion_area_body_exited)

    _fire_timer.timeout.connect(_on_fire_timer_timeout)
    detection_area.body_exited.connect(_on_detection_area_body_exited)
```

**Note:** `set_collision_layer_value(n, bool)` (1-indexed) is equivalent but GDScript integer assignment is cleaner for a full reset. The `_ready()` in `EnemyShip` already configures `detection_area` layer/mask; CohesionArea is a separate node and must be configured here.

### Pattern 3: Angle Offset Application During SEEKING

The cleanest approach is to rotate the direction vector inline before calling `apply_central_force`, rather than computing a rotated target point or calling `steer_toward()` with a modified position. This keeps `steer_toward()` untouched and makes the offset explicit.
[VERIFIED: EnemyShip.steer_toward() reads from components/enemy-ship.gd]

```gdscript
# In _tick_state, SEEKING branch:
State.SEEKING:
    if dist <= fight_range:
        _change_state(State.FIGHTING)
    else:
        # Apply angle offset to steering direction (not to target position)
        var raw_dir := (to_target / dist)
        var offset_dir := raw_dir.rotated(_angle_offset)
        var force_scale := cohesion_thrust_scale if _nearby_swarmers.size() > 0 else 1.0
        apply_central_force(offset_dir * thrust * force_scale)
        rotation = linear_velocity.angle()
```

**Why not use steer_toward() with a modified position:** Computing a rotated target point requires choosing an arbitrary distance, which makes the behavior distance-dependent. Rotating the direction vector is distance-independent and matches the intent of D-04/D-05.

### Pattern 4: FIGHTING State

Mirror the Flanker's FIGHTING tick — steer toward player, aim, fire via timer. Add cohesion scale.
[VERIFIED: components/flanker.gd]

```gdscript
State.FIGHTING:
    var target_angle := to_target.angle()
    rotation = lerp_angle(rotation, target_angle, 5.0 * _delta)
    # Cohesion scale applies in FIGHTING too (D-08)
    var force_scale := cohesion_thrust_scale if _nearby_swarmers.size() > 0 else 1.0
    apply_central_force((to_target / dist) * thrust * force_scale)
    # Hysteresis: return to SEEKING if player leaves fight range + buffer
    if dist > fight_range * 1.2:
        _change_state(State.SEEKING)
```

### Pattern 5: Separation Force (Per-Frame in _physics_process)

Applied in `_physics_process` after `_tick_state`. Uses linear falloff to avoid divide-by-zero and jitter at close range. [VERIFIED: applied force pattern consistent with ENM-03, EnemyShip._integrate_forces]

```gdscript
func _physics_process(delta: float) -> void:
    super(delta)  # calls queue_redraw() + dying guard + _tick_state
    if dying:
        return
    _apply_separation()

func _apply_separation() -> void:
    for swarmer in _nearby_swarmers:
        if not is_instance_valid(swarmer):
            continue
        var away: Vector2 = global_position - swarmer.global_position
        var dist: float = away.length()
        if dist < 1.0:
            continue  # coincident — skip to avoid NaN
        # Linear falloff: max force at dist=0, zero force at dist=cohesion_radius
        var strength: float = separation_force * (1.0 - clampf(dist / cohesion_radius, 0.0, 1.0))
        apply_central_force(away.normalized() * strength)
```

**Key detail:** `_apply_separation()` is called AFTER `super(delta)` which already called `_tick_state`. The `dying` guard is re-checked because `_tick_state` could trigger death. The `is_instance_valid()` check handles the dead-Swarmer window (see Pitfall 1).

### Pattern 6: CohesionArea Signal Handlers

```gdscript
func _on_cohesion_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is Swarmer and body != self:
        _nearby_swarmers.append(body)

func _on_cohesion_area_body_exited(body: Node2D) -> void:
    _nearby_swarmers.erase(body)
```

**Why `body != self` check:** In Godot 4, an Area2D's signals do not fire for the Area2D's own parent RigidBody2D (the area detects OTHER physics bodies). However, since the Swarmer's root RigidBody2D is on Layer 1 and the CohesionArea mask also detects Layer 1, it will detect OTHER Swarmers' RigidBody2D roots. The `body != self` guard is a safety net in case a pathological scene setup triggers self-detection.

**Why `body is Swarmer`:** The player ship is also on Layer 1 (Ship). Without this filter, the Swarmer would treat the player as a groupmate and reduce thrust when approaching — a bug that would prevent the swarm from ever reaching fight range.

### Pattern 7: State Transitions and Timer Lifecycle

```gdscript
func _enter_state(new_state: State) -> void:
    print("[Swarmer] _enter_state: %s" % State.keys()[new_state])
    if new_state == State.FIGHTING:
        _fire()
        _fire_timer.start()

func _exit_state(old_state: State) -> void:
    if old_state == State.FIGHTING:
        _fire_timer.stop()
```

### Pattern 8: Fire and Die Overrides

Exact Beeliner/Flanker pattern. [VERIFIED: components/beeliner.gd, components/flanker.gd]

```gdscript
func _fire() -> void:
    if dying:
        return
    var bullet := _bullet_scene.instantiate() as RigidBody2D
    var fire_dir := Vector2.from_angle(global_rotation)
    bullet.rotation = global_rotation
    bullet.linear_velocity = fire_dir * bullet_speed
    if spawn_parent:
        spawn_parent.add_child(bullet)
        bullet.global_position = _barrel.global_position
    else:
        push_warning("Swarmer: spawn_parent not set")

func _on_fire_timer_timeout() -> void:
    if dying or current_state != State.FIGHTING:
        return
    _fire()

func die(delay: float = 0.0) -> void:
    if dying:
        return
    _fire_timer.stop()
    _ammo_dropper.drop()
    super(delay)
```

### Pattern 9: Detection Area Wiring

Flanker pattern — override both entered and exited. [VERIFIED: components/flanker.gd]

```gdscript
func _on_detection_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip and current_state == State.IDLING:
        _target = body
        _change_state(State.SEEKING)

func _on_detection_area_body_exited(body: Node2D) -> void:
    if body == _target:
        _target = null
        _change_state(State.IDLING)
```

### Pattern 10: _tick_state Guard

Flanker pattern — validate target every tick. [VERIFIED: components/flanker.gd]

```gdscript
func _tick_state(delta: float) -> void:
    if not is_instance_valid(_target):
        _target = null
        _change_state(State.IDLING)
        return

    var to_target: Vector2 = _target.global_position - global_position
    var dist: float = to_target.length()
    # ... match current_state
```

### Anti-Patterns to Avoid

- **Direct linear_velocity assignment in _tick_state:** ENM-03 prohibits this; max_speed clamping is in `_integrate_forces` via `state.linear_velocity.limit_length(max_speed)`.
- **Using steer_toward() with cohesion scale:** `steer_toward()` in EnemyShip always applies `thrust` at full scale. Call `apply_central_force()` directly in Swarmer so the cohesion scale can be applied inline.
- **Applying separation in _integrate_forces:** `_integrate_forces` receives `PhysicsDirectBodyState2D` and is used only for velocity clamping. Adding force accumulation there creates ordering complexity; use `_physics_process` instead.
- **Inverse-square falloff for separation:** `separation_force / dist_squared` explodes as dist → 0. Linear falloff `separation_force * (1 - dist/cohesion_radius)` is smooth and bounded.
- **Not guarding is_instance_valid in _apply_separation:** Dead Swarmers may remain in the array for one physics frame after `queue_free()`. Without the guard, `swarmer.global_position` will crash.

---

## Bullet Scene: Confirmed Structure

Read directly from `prefabs/enemies/beeliner/beeliner-bullet.tscn`. [VERIFIED: file read]

```
BeelinerBullet (RigidBody2D)
  script: components/enemy-bullet.gd
  collision_layer: 256  (Layer 9 — established enemy bullet layer)
  collision_mask: 1     (Layer 1 = Ship — bullet detects Ship bodies via body_entered)
  gravity_scale: 0.0
  mass: 50.0
  contact_monitor: true
  max_contacts_reported: 100
  attack: sub_resource Damage (energy=5.0, kinetic=0.0)  -- embedded, not external .tres
  death: minigun-bullet-explosion.tscn
  life: 2.0
  ├── Sprite2D (rotation = 1.5708, no texture assigned)
  └── CollisionShape2D (RectangleShape2D, size=Vector2(12,84), rotation=1.5708)
```

**IMPORTANT — Layer 9, not Layer 3:** The CONTEXT.md comment "Swarmer bullet: layer 3 (Bullets)" is a documentation error inherited from the physics table comment. All existing enemy bullets (`beeliner-bullet.tscn`, `flanker-bullet.tscn`) use `collision_layer = 256` (Layer 9). The `swarmer-bullet.tscn` must also use `collision_layer = 256`. Layer 3 (value 4) is used by player bullets (see `minigun-bullet.tscn`). [VERIFIED: both bullet scenes read]

**Swarmer bullet .tscn should be:**
- Node name: `SwarmerBullet`
- `collision_layer = 256` (Layer 9)
- `collision_mask = 1` (Layer 1 = Ship)
- `Damage.energy` lower than Beeliner's 5.0 (e.g., 2.0 or 3.0 — at discretion)
- `mass`: slightly lighter than Beeliner's 50.0 (e.g., 30.0, matching Flanker)
- `RectangleShape2D` collision shape (same as all other bullets)

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Proximity detection | Manual distance loop in `_physics_process` every frame | `Area2D` body_entered/exited signals + `_nearby_swarmers` array | Godot handles overlap tracking; signal-driven array is O(events) not O(n²) |
| Max speed clamp | Direct `linear_velocity` assignment | `_integrate_forces` → `state.linear_velocity.limit_length(max_speed)` | ENM-03; direct assignment fights the physics engine |
| Angle rotation | Manual sin/cos | `Vector2.rotated(angle)` | Built-in, no error accumulation |
| Lerped rotation | Manual angle math | `lerp_angle(rotation, target_angle, speed * delta)` | Handles wrap-around correctly |
| Timer management | Custom float countdown | Godot `Timer` node | Already proven by Beeliner and Flanker |
| Bullet spawn | `get_tree().current_scene.add_child()` | `spawn_parent.add_child()` | ENM-05; spawn_parent propagated by WaveManager |

---

## Common Pitfalls

### Pitfall 1: Dead Swarmer Stays in _nearby_swarmers Array
**What goes wrong:** A Swarmer dies and calls `queue_free()`. The deferred free executes at end of frame. In the current physics frame, `_apply_separation()` iterates `_nearby_swarmers` and calls `swarmer.global_position` on the freed instance → crash or stale data.
**Why it happens:** In Godot 4, `queue_free()` is deferred. The `body_exited` signal from CohesionArea fires when the physics body is actually removed, which may be one frame after `dying = true` and `queue_free()` are called in `Body.die()`.
**How to avoid:** Always guard with `is_instance_valid(swarmer)` before accessing any property in `_apply_separation()`. Already shown in Pattern 5.
**Warning signs:** Crash with "Invalid get index 'global_position' on base 'previously freed instance'" when enemies die in proximity.

### Pitfall 2: Player Ship Triggers Cohesion Thrust Reduction
**What goes wrong:** Player enters CohesionArea → `body is Swarmer` returns false (PlayerShip is not Swarmer) → array stays empty. This works correctly. BUT: if the `body is Swarmer` check is missing or replaced with a group check, the player will cause thrust reduction. The swarm stops accelerating toward the player when the player is nearby — the opposite of desired behavior.
**How to avoid:** Use `body is Swarmer` in both `_on_cohesion_area_body_entered` and `_on_cohesion_area_body_exited`. [VERIFIED: class_name Swarmer with `is` check is reliable in Godot 4 per confirmed GDScript class_name semantics]
**Warning signs:** Swarmers slow to a crawl when the player is inside the CohesionArea, even with no other Swarmers present.

### Pitfall 3: Angle Offset Oscillates (Using Runtime Angle)
**What goes wrong:** Offset is recalculated each frame in `_tick_state` using `randf_range()`, causing each Swarmer to drift randomly rather than converging on a stable vector.
**How to avoid:** Set `_angle_offset` exactly once in `_ready()`. It is a constant per-instance, not a per-frame value (D-05).
**Warning signs:** Visual jitter in Swarmer approach paths; Swarmers don't hold their spread angle.

### Pitfall 4: Cohesion Force Applies Even to Dead Self (dying Flag)
**What goes wrong:** `_physics_process` is still called briefly after `dying = true` (during the die delay). Separation force calculations run on a dying Swarmer, pushing it erratically.
**How to avoid:** The `dying` guard at the top of `_physics_process` via `super(delta)` already returns early if `dying` is true. Since `_apply_separation()` is called after `super(delta)` which contains the guard — but `super(delta)` doesn't `return` from the calling function. Add explicit guard before `_apply_separation()`.
**Warning signs:** Dying Swarmer jolts sideways unexpectedly.

Corrected code:
```gdscript
func _physics_process(delta: float) -> void:
    super(delta)
    if dying:
        return
    _apply_separation()
```

**Note:** `super(delta)` calls `EnemyShip._physics_process` which also checks `if dying: return` before `_tick_state`. The guard in the Swarmer override ensures `_apply_separation()` is also skipped.

### Pitfall 5: Beeliner Does Not Use _barrel for Spawn — Swarmer Must
**What goes wrong:** Beeliner's `_fire()` spawns at `global_position + fire_dir * 350.0` (offset from center), NOT at `$Barrel.global_position`. This was a workaround to avoid self-collision with the HitBox. Flanker DOES use `_barrel.global_position`.
**How to avoid:** Swarmer should use `_barrel.global_position` (Flanker pattern, D-03). If the barrel is positioned outside the HitBoxShape radius (radius = 300 for Beeliner/Flanker, Barrel position = Vector2(40,0)), you may need to place the barrel further out. For the debug circle ship with collision radius 300, place Barrel at Vector2(350, 0) or use the `global_position + fire_dir * 350.0` offset as a fallback if self-collision occurs in testing.
**Warning signs:** Swarmer bullets immediately collide with own HitBox on spawn.

### Pitfall 6: CohesionArea CollisionShape2D Size Must Bound Cohesion Radius
**What goes wrong:** `cohesion_radius` export is set in GDScript but the CohesionArea's `CollisionShape2D` shape radius in the `.tscn` does not match. The Area2D won't detect anything beyond its physical shape — the export var has no effect on detection range.
**How to avoid:** In `swarmer.tscn`, set the CohesionArea's `CircleShape2D` radius to match (or slightly exceed) the `cohesion_radius` export default (e.g., if `cohesion_radius = 700.0`, set `CircleShape2D.radius = 700.0`). If `cohesion_radius` needs runtime adjustment, resize the shape dynamically in `_ready()`:
```gdscript
var cohesion_shape := _cohesion_area.get_node("CohesionShape").shape as CircleShape2D
cohesion_shape.radius = cohesion_radius
```
**Warning signs:** Cohesion never triggers; `_nearby_swarmers` always empty.

---

## Implementation Notes (Research Question Answers)

### Q1: Area2D body_entered/exited reliability vs. get_overlapping_bodies()

**Answer:** `Area2D.body_entered/body_exited` signals are reliable for maintaining an array. Use them. [VERIFIED: EnemyShip._ready() uses this exact pattern for detection_area]

`get_overlapping_bodies()` polled every frame is wasteful (allocates a new Array each call) and still has the same dead-instance problem. The signal approach + `is_instance_valid()` guard is correct.

The one genuine reliability concern is: when a Swarmer is `queue_free()`'d, `body_exited` fires during the next physics step when the body is actually removed from the physics server. Between `dying = true` (in `Body.die()`) and the actual removal, the body is still physically present. So `body_exited` will fire. The array cleanup will happen within 1–2 physics frames. The `is_instance_valid()` guard covers the window between `queue_free()` and the signal firing.

### Q2: Force application timing — _physics_process vs. _integrate_forces

**Answer:** Use `_physics_process` for both steering forces and separation forces. [VERIFIED: ENM-03 requires `apply_central_force`; `_integrate_forces` in EnemyShip is used only for velocity clamping]

`_integrate_forces` receives `PhysicsDirectBodyState2D` and is designed for velocity/state manipulation that must be applied atomically. The existing `_integrate_forces` override does exactly one thing: `state.linear_velocity.limit_length(max_speed)`. Adding force accumulation there would require accessing `_nearby_swarmers` inside the physics server callback, which works but couples AI logic to the physics callback unnecessarily.

`apply_central_force` called from `_physics_process` is queued and applied at the next physics integration step — the standard Godot pattern for physics-process-driven AI. Forces from multiple Swarmers accumulate correctly; the physics engine sums all pending forces before integrating.

### Q3: Angle offset application

**Answer:** Rotate the direction vector by `_angle_offset` inline in `_tick_state`, before calling `apply_central_force`. Do NOT use `steer_toward()` for SEEKING in the Swarmer. [VERIFIED: steer_toward() in enemy-ship.gd always applies full thrust with no scale parameter]

`steer_toward(target_position)` computes `(target_position - global_position).normalized() * thrust` and calls `apply_central_force`. It does not accept a scale parameter and does not accept a pre-rotated direction. Since the Swarmer needs both offset AND cohesion scaling, inline the force call:

```gdscript
var raw_dir := to_target / dist
var offset_dir := raw_dir.rotated(_angle_offset)
var scale := cohesion_thrust_scale if _nearby_swarmers.size() > 0 else 1.0
apply_central_force(offset_dir * thrust * scale)
```

Option (b) — computing a rotated target point at `global_position + offset_dir * dist` and passing to `steer_toward()` — would also work mathematically, but it's roundabout and conceals the cohesion scale issue (steer_toward can't apply it). Option (c) — inline — is cleanest.

### Q4: Separation force formula

**Answer:** Use linear falloff: `separation_force * (1.0 - clampf(dist / cohesion_radius, 0.0, 1.0))`. [ASSUMED — based on common game AI practice; inverse-square behavior verified to cause jitter by reasoning about close-range values]

**Why not inverse-square (`separation_force / dist_squared`):** At dist = 1 unit, force = separation_force. At dist = 0.1 units, force = separation_force * 100. Two Swarmers that spawn overlapping will experience extreme repulsion, causing them to shoot apart at high velocity — the opposite of a cluster. Linear falloff produces:
- dist = 0: full separation_force
- dist = cohesion_radius/2: half separation_force
- dist = cohesion_radius: zero force

This is smooth, bounded, and graceful under spawn overlap.

**Zero-distance guard:** Always check `if dist < 1.0: continue` before computing direction or falloff. Coincident positions (can occur at spawn) produce undefined direction after `.normalized()`.

### Q5: CohesionArea layer/mask in GDScript

**Answer:** Set `collision_layer = 0` and `collision_mask = 1` using integer assignment in `_ready()`, after the node is in the scene tree. [VERIFIED: EnemyShip._ready() uses `set_collision_layer_value(1, false)` / `set_collision_mask_value(1, true)` — both approaches work. Integer assignment is simpler for full reset from known initial state]

```gdscript
# In swarmer.tscn: CohesionArea has default collision_layer=1, collision_mask=1
# Override in _ready() to ensure exact values regardless of .tscn default:
_cohesion_area.collision_layer = 0   # area itself is on no layer (doesn't block anything)
_cohesion_area.collision_mask = 1    # detects Layer 1 (Ship) bodies — all Swarmers + player
```

The Area2D's CollisionShape2D needs `monitorable = false` (the area doesn't need to be detectable by other areas) and `monitoring = true` (it does need to fire signals). These are Godot defaults for new Area2D nodes.

The CohesionArea does NOT interfere with DetectionArea (which also masks Layer 1) — two Area2D nodes on the same parent can both independently monitor the same layer without conflict.

### Q6: `body is Swarmer` class_name check reliability

**Answer:** Reliable in Godot 4 GDScript. [VERIFIED: EnemyShip uses `body is PlayerShip` and `body is Bullet` throughout — same pattern confirmed working across 3 enemy types]

`class_name Swarmer extends EnemyShip` registers the class globally. Any instance of `swarmer.tscn` will pass `body is Swarmer`. Instances of `Beeliner`, `Flanker`, `Sniper` will NOT pass `body is Swarmer` — they fail the test correctly because they have their own distinct `class_name`. An `EnemyShip` instance (base class) also fails `is Swarmer`.

Edge case: if multiple Swarmer scenes with different `class_name` values exist (e.g., `class_name SwarmerV2`), they would not pass `body is Swarmer`. This is not a concern for Phase 8.

### Q7: Dead Swarmer cleanup from _nearby_swarmers

**Answer:** When a Swarmer dies and `queue_free()` is called, Godot 4 will fire `body_exited` on any Area2D that was overlapping it — but this fires with a 1-frame delay (deferred). The array will be cleaned by `_on_cohesion_area_body_exited` within 1–2 physics frames. During that window, the stale reference in `_nearby_swarmers` is a freed instance. [ASSUMED — based on Godot 4 physics server deferred free behavior; consistent with documented queue_free semantics]

**Mitigation:** `is_instance_valid()` guard in `_apply_separation()` (Pattern 5). No other guard is needed; `_on_cohesion_area_body_exited` handles cleanup when the signal fires. Do NOT proactively filter the array every frame — the signal-driven erase is sufficient.

### Q8: Beeliner bullet scene structure confirmed

**Answer:** Confirmed by reading `prefabs/enemies/beeliner/beeliner-bullet.tscn` directly. [VERIFIED: file read]

Structure:
- Root: `RigidBody2D` with `EnemyBullet` script (`components/enemy-bullet.gd`)
- `collision_layer = 256` (Layer 9 — NOT Layer 3)
- `collision_mask = 1` (Layer 1 = Ship)
- `gravity_scale = 0.0`, `mass = 50.0`, `contact_monitor = true`, `max_contacts_reported = 100`
- Damage: **embedded sub_resource** (not external `.tres`): `energy = 5.0, kinetic = 0.0`
- `death`: `minigun-bullet-explosion.tscn` (shared with player bullets)
- `life = 2.0`
- Child `Sprite2D` (no texture, rotation = 1.5708)
- Child `CollisionShape2D` with `RectangleShape2D(size=Vector2(12,84))`, rotation = 1.5708

Flanker bullet is identical in structure with `mass = 30.0` and `size = Vector2(10,70)`. Swarmer bullet should use `mass` and shape size proportional to lower threat level.

---

## Code Examples

### Cohesion Area Setup (complete _ready fragment)
```gdscript
# Source: verified against EnemyShip._ready() pattern in components/enemy-ship.gd
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    _angle_offset = deg_to_rad(randf_range(-40.0, 40.0))

    _cohesion_area.collision_layer = 0
    _cohesion_area.collision_mask = 1

    # Sync shape radius to export default
    var shape := _cohesion_area.get_node("CohesionShape").shape as CircleShape2D
    if shape:
        shape.radius = cohesion_radius

    _cohesion_area.body_entered.connect(_on_cohesion_area_body_entered)
    _cohesion_area.body_exited.connect(_on_cohesion_area_body_exited)
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
    detection_area.body_exited.connect(_on_detection_area_body_exited)
```

### Separation Force Application
```gdscript
# Source: established apply_central_force pattern from enemy-ship.gd + linear falloff reasoning
func _apply_separation() -> void:
    for swarmer in _nearby_swarmers:
        if not is_instance_valid(swarmer):
            continue
        var away: Vector2 = global_position - swarmer.global_position
        var dist: float = away.length()
        if dist < 1.0:
            continue
        var strength: float = separation_force * (1.0 - clampf(dist / cohesion_radius, 0.0, 1.0))
        apply_central_force(away.normalized() * strength)
```

### swarmer-bullet.tscn Structure
```
[gd_scene load_steps=6 format=3 uid="uid://swarmer_bullet_001"]

[ext_resource type="Script" path="res://components/enemy-bullet.gd" id="1_bullet"]
[ext_resource type="PackedScene" uid="uid://b8d4dssoxnkg2" path="res://prefabs/minigun/minigun-bullet-explosion.tscn" id="2_explosion"]
[ext_resource type="Script" path="res://components/damage.gd" id="3_damage"]

[sub_resource type="Resource" id="Resource_damage"]
script = ExtResource("3_damage")
energy = 2.0
kinetic = 0.0

[sub_resource type="RectangleShape2D" id="RectangleShape2D_shape"]
size = Vector2(8, 60)

[node name="SwarmerBullet" type="RigidBody2D"]
collision_layer = 256
collision_mask = 1
gravity_scale = 0.0
mass = 20.0
max_contacts_reported = 100
contact_monitor = true
script = ExtResource("1_bullet")
attack = SubResource("Resource_damage")
death = ExtResource("2_explosion")
life = 2.0

[node name="Sprite2D" type="Sprite2D" parent="."]
rotation = 1.5708

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
rotation = 1.5708
shape = SubResource("RectangleShape2D_shape")
```

### swarmer.tscn Node Structure (additions over base-enemy-ship.tscn)
```
Swarmer (RigidBody2D)          -- inherits base-enemy-ship.tscn? No — full scene, same as Beeliner
  script: components/swarmer.gd
  collision_layer = 1, collision_mask = 3
  max_health = 15               -- lower than Beeliner (30)
  max_speed = 2200.0
  thrust = 1600.0
  ...
  ├── CollisionShape2D (CircleShape2D radius=300)
  ├── Sprite2D
  ├── DetectionArea (Area2D, layer=0, mask=1)
  │   └── DetectionShape (CircleShape2D radius=10000)
  ├── HitBox (Area2D, layer=0, mask=4)
  │   └── HitBoxShape (CircleShape2D radius=300)
  ├── Barrel (Node2D, position=Vector2(350,0))  -- further out than base (40) to avoid self-hit
  ├── CoinDropper (Node2D, ItemDropper script)
  ├── FireTimer (Timer, wait_time=0.8, one_shot=false, autostart=false)
  ├── AmmoDropper (Node2D, ItemDropper script)
  └── CohesionArea (Area2D, layer=0, mask=1)
      └── CohesionShape (CollisionShape2D, CircleShape2D radius=700)
```

**Scene inheritance note:** Beeliner and Flanker do NOT use `[ext_resource ... base-enemy-ship.tscn]` as a parent via scene inheritance — they are fully standalone `.tscn` files that duplicate the base structure. The CONTEXT.md D-14 says "inherits base-enemy-ship.tscn" but the actual pattern (confirmed by reading `beeliner.tscn` and `flanker.tscn`) is that they are standalone scenes with identical node structure. Follow the same pattern for Swarmer — full standalone `.tscn` with all nodes defined inline. [VERIFIED: beeliner.tscn and flanker.tscn read]

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `get_tree().current_scene.add_child(bullet)` | `spawn_parent.add_child(bullet)` | ENM-05 — established in Phase 4 |
| Direct `linear_velocity` assignment for steering | `apply_central_force` + `_integrate_forces` clamp | ENM-03 — established in Phase 4 |
| Single detection Area2D | Separate DetectionArea (IDLING→SEEKING) + HitBox (bullet hit) + CohesionArea (proximity) | Clean separation of concerns |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `body_exited` fires within 1–2 physics frames after `queue_free()` on the detected body | Q7, Pitfall 1 | If signal never fires, `_nearby_swarmers` leaks stale references permanently — `is_instance_valid()` guard prevents crash but dead entries accumulate; fix: filter invalid entries in `_apply_separation` and don't re-add |
| A2 | Linear falloff separation force avoids jitter better than inverse-square at close range | Q4, Pattern 5 | If inverse-square turns out to be needed for effective separation, jitter at spawn overlap would require adding a min-distance clamp |
| A3 | `collision_layer = 0` on CohesionArea means the area itself doesn't occupy any layer | Q5 | Standard Godot behavior; if wrong (unlikely), separation detection might accidentally trigger bullet collisions — trivially debuggable |

---

## Open Questions

1. **Barrel position to avoid self-hit**
   - What we know: Beeliner uses `global_position + fire_dir * 350.0` (offset past HitBoxShape radius 300). Flanker uses `_barrel.global_position` with Barrel at `Vector2(40, 0)` — very close to center.
   - What's unclear: Does Flanker avoid self-collision because `EnemyBullet.collision()` returns early for `EnemyShip` bodies? (Yes — `enemy-bullet.gd` returns if `body is EnemyShip`). So self-collision is NOT an issue for enemy bullets hitting their own ship via HitBox, because HitBox detects player bullets (mask=4, Layer 3), not enemy bullets (layer 256, Layer 9).
   - Resolution: Place Barrel at `Vector2(350, 0)` for clarity and visual accuracy. Self-collision is not a risk due to layer separation.

---

## Environment Availability

Step 2.6: SKIPPED — phase is code/config-only changes to the Godot project. No external tools, CLIs, databases, or services required beyond the Godot 4 editor already installed.

---

## Sources

### Primary (HIGH confidence)
- `components/enemy-ship.gd` — EnemyShip base class read directly; steer_toward(), _integrate_forces, _ready() Area2D setup
- `components/flanker.gd` — Range-based transitions, fire timer, detection body_exited pattern
- `components/beeliner.gd` — Fire loop, die() override, _ready() randomization
- `components/body.gd` — dying flag, queue_free(), spawn_parent propagation
- `prefabs/enemies/beeliner/beeliner-bullet.tscn` — Bullet scene structure confirmed (layer 256, embedded damage, RectangleShape2D)
- `prefabs/enemies/flanker/flanker-bullet.tscn` — Second bullet confirmation
- `prefabs/enemies/beeliner/beeliner.tscn` — Full concrete scene structure confirmed
- `prefabs/enemies/flanker/flanker.tscn` — Scene structure cross-reference
- `prefabs/enemies/base-enemy-ship.tscn` — Base scene node layout confirmed
- `components/enemy-bullet.gd` — EnemyShip self-collision guard confirmed
- `world.gd` — Physics layer table confirmed (1=Ship...8=WeaponItem)
- `components/wave-manager.gd` — Wave structure, tree_exiting counter pattern

### Secondary (MEDIUM confidence)
- `prefabs/minigun/minigun-bullet.tscn` — Player bullet uses `collision_layer = 4` (Layer 3), confirming enemy bullets correctly use Layer 9 (256) to avoid layer conflict

### Tertiary (LOW confidence)
- A1, A2, A3 in Assumptions Log — reasoning from code patterns, not explicit Godot documentation

---

## Metadata

**Confidence breakdown:**
- Bullet scene structure: HIGH — read directly from file
- CohesionArea layer/mask setup: HIGH — verified against EnemyShip._ready() pattern
- Angle offset application: HIGH — steer_toward() source read, inline approach confirmed
- Separation force formula: MEDIUM — linear falloff reasoning is sound; exact tuning values are discretionary
- Dead-Swarmer cleanup timing: MEDIUM — queue_free deferred behavior is well-known Godot pattern; body_exited signal timing is assumed consistent

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (stable Godot 4 patterns; valid until engine upgrade to 4.6.2 which may change physics callbacks)
