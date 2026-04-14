# Domain Pitfalls: Enemy AI on a RigidBody2D Space Shooter

**Domain:** State-machine AI for physics-based enemy ships in Godot 4.6.2
**Researched:** 2026-04-11
**Overall confidence:** HIGH (Godot-specific pitfalls verified against official docs and community sources; codebase-specific pitfalls derived from direct code inspection)

---

## Critical Pitfalls

Mistakes in this section cause silent failures, crashes, or rewrites.

---

### Pitfall C-1: AI Tick Running After `die()` Is Called

**What goes wrong:** `_physics_process` or a state-machine tick runs one or more frames after `Body.die()` is called and `dying = true` is set, because `queue_free()` defers removal to end-of-frame. The enemy is mid-death but its state machine still executes — it may fire bullets, call methods on already-freed nodes, or transition states that operate on null references.

**Why it happens:** `Body.die()` sets `dying = true` and calls `queue_free()`, but the node stays in the tree and receives `_physics_process` calls until the frame boundary. If the state machine has no guard at entry, it runs one final tick in an invalid state.

**Consequences:** Null reference errors on freed child nodes (barrel, Area2D detector), bullets spawned at the moment of death, wave completion logic that fires while an enemy still appears alive.

**Prevention:** Guard every state-machine tick method and every `_physics_process` override with the `dying` flag inherited from `Body`:

```gdscript
func _physics_process(delta: float) -> void:
    if dying:
        return
    _tick_state(delta)
```

Also guard the fire method:

```gdscript
func fire() -> void:
    if dying or not is_instance_valid(spawn_parent):
        return
    ...
```

**Detection:** Intermittent "attempt to call method on null instance" errors that only appear when an enemy dies while firing. Bullets appear at position (0, 0) on enemy death.

---

### Pitfall C-2: Fighting the Physics Engine With Direct Velocity Assignment

**What goes wrong:** Setting `linear_velocity` directly every frame in `_physics_process` bypasses the physics integrator. The engine resets or partially overrides that value each step, producing jitter, incorrect collision responses, and impulses that have no effect (recoil from `MountableBody.do(Action.RECOIL)` gets overwritten immediately).

**Why it happens:** `RigidBody2D` in Godot 4 owns its velocity; external writes during `_physics_process` happen *before* the integrator runs and are overwritten. The only safe place to write velocity directly is inside `_integrate_forces(state: PhysicsDirectBodyState2D)`.

**Consequences:** Enemy ships ignore collision impulses from asteroids, bullets, and the gravity gun shockwave. The existing `Body._on_body_entered` kinetic damage formula (`speed / 10.0`) still fires, but the ship doesn't physically react — the experience is inconsistent.

**Prevention:** Use `apply_force()` (continuous thrust, per-frame) or `apply_central_impulse()` (one-shot kick) from `_physics_process`. Never write `linear_velocity = X` from `_physics_process`. If velocity clamping is needed for a max-speed cap, use `_integrate_forces`:

```gdscript
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    if dying:
        return
    # Cap top speed without fighting the integrator
    if state.linear_velocity.length() > MAX_SPEED:
        state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)
```

**Detection:** Enemy ignores explosion shockwaves. Recoil from enemy weapons has no effect. Ships clip through asteroids at high speed.

---

### Pitfall C-3: Detection Area Layer/Mask Mismatch Silently Disables AI

**What goes wrong:** An `Area2D` used for enemy detection (vision range, proximity trigger) never fires `body_entered` or `body_exited` because its collision mask does not include the layer of the target body.

**Why it happens:** The project defines physics layers in `world.gd` comments (layer 1 = Ship, 2 = Weapons, 3 = Bullets, 4 = Asteroids, 5 = Explosions, 6 = Coins, 7 = Ammo, 8 = Weapon Items). Area2D signals only fire when the Area2D's **mask** includes the target's **layer**. Forgetting this produces a completely silent failure — no error, no signal.

**Consequences:** AI never detects the player, stays in IDLING forever. Or detects asteroids it should not, triggering fight behavior against rocks.

**Prevention:** For a detection area that should see only ships, set it explicitly in code:

```gdscript
detection_area.collision_layer = 0          # area emits no collisions of its own
detection_area.collision_mask = 0           # clear all first
detection_area.set_collision_mask_value(1, true)   # detect layer 1 (Ships)
```

Add a comment citing the world.gd layer table so the mapping is traceable. Verify in the Godot editor's collision matrix view during integration testing.

**Detection:** AI stays in IDLING state regardless of player position. Adding `print()` inside `_on_body_entered` shows it never executes.

---

### Pitfall C-4: `spawn_parent` Not Propagated to Enemy Bullets

**What goes wrong:** Enemy fire logic instantiates bullets directly via `spawn_parent.add_child()` or `get_tree().current_scene.add_child()`. If `spawn_parent` is null (enemy was not set up through `world.gd`'s `setup_spawn_parent`), bullets spawn as orphans or crash with a null dereference. Using `get_tree().current_scene` was explicitly removed as a v1.0 bug fix (BUG-03) — reintroducing it in enemy fire breaks the established pattern.

**Why it happens:** The simplified enemy fire path (not using `MountableWeapon`) must still follow the `spawn_parent` propagation convention. It is easy to shortcut this when writing simplified fire code.

**Consequences:** Bullets appear at position (0, 0), NullReferenceError on fire, or bullets land in the wrong scene-tree location and don't interact with the existing collision groups.

**Prevention:** Enemy fire code must use the same pattern as `MountableWeapon.fire()`:

```gdscript
func fire() -> void:
    if dying or not spawn_parent:
        push_warning("EnemyShip %s: spawn_parent not set, cannot fire" % name)
        return
    var bullet = bullet_scene.instantiate() as RigidBody2D
    bullet.global_position = barrel.global_position
    if "spawn_parent" in bullet:
        bullet.spawn_parent = spawn_parent
    spawn_parent.call_deferred("add_child", bullet)
```

**Detection:** Bullets appear at wrong position on first enemy fire. `push_warning` output in the Godot output panel.

---

## Moderate Pitfalls

---

### Pitfall M-1: State Transitions That Immediately Re-Enter the Same State

**What goes wrong:** A state's exit condition evaluates to true before the state has meaningfully executed, causing rapid IDLING → SEEKING → IDLING oscillation (or similar). This produces jitter, wasted calls, and logic that never settles.

**Why it happens:** Transition logic uses the same condition for entry and re-evaluation. Example: SEEKING checks `player_in_range()` on entry, but the detection radius and the seek radius overlap, so the enemy immediately transitions back to IDLING when it reaches the boundary.

**Consequences:** Enemy visually vibrates. Firing state never activates because the state machine oscillates before reaching it.

**Prevention:** Use hysteresis — different thresholds for entering and leaving a state:

```gdscript
const SEEK_ENTER_RANGE = 1200.0
const SEEK_EXIT_RANGE  = 1500.0   # larger than enter

func _should_seek() -> bool:
    return distance_to_player < SEEK_ENTER_RANGE

func _should_stop_seeking() -> bool:
    return distance_to_player > SEEK_EXIT_RANGE
```

**Detection:** Enemy oscillates visually at the boundary of two states. State change print logs show rapid alternation with no sustained state duration.

---

### Pitfall M-2: `get_tree().create_timer()` in State Logic Creates Orphaned Timers on Death

**What goes wrong:** A state uses `await get_tree().create_timer(t).timeout` for delays (e.g., lurking duration, patrol pause). If the enemy dies during the wait, the node is freed but the `SceneTreeTimer` continues running. When it fires, it attempts to resume execution on the freed node, producing errors.

**Why it happens:** `SceneTreeTimer` is owned by the `SceneTree`, not by the node. `queue_free()` does not cancel it.

**Consequences:** "Attempt to call function on a freed object" errors after enemy death during timed states.

**Prevention:** Use a `Timer` node child (as `MountableWeapon` does for `shot_timer` and `reload_timer`) rather than `SceneTreeTimer`. A `Timer` node is freed with its parent, so its `timeout` signal never fires after `queue_free()`. If `create_timer` must be used, add an `is_instance_valid(self)` guard after the await — or skip it entirely in favor of `Timer` nodes.

**Detection:** Console errors occur only after enemies die during a delay-state (lurking, patrolling).

---

### Pitfall M-3: `body_entered` Signal Spam From Sustained Contact

**What goes wrong:** An `Area2D` used for detection fires `body_entered` once and `body_exited` once, not continuously — this is correct. But if the detection area is also used for combat (e.g., Suicider proximity damage), and the Suicider bumps against the player repeatedly due to physics, `body_entered` fires on each new contact, triggering multiple damage calls per second.

**Why it happens:** `RigidBody2D` bodies can briefly separate and re-enter an Area2D during physics jitter, especially when both objects are RigidBody2D and have small mass differences. Each separation-and-reentry fires a new `body_entered`.

**Consequences:** Suicider deals many times its intended damage. Contact damage is framerate-sensitive.

**Prevention:** For contact damage, track whether the target is already inside the area using a Set and only apply damage on initial entry:

```gdscript
var bodies_inside: Dictionary = {}

func _on_area_body_entered(body: Node2D) -> void:
    if body in bodies_inside:
        return
    bodies_inside[body] = true
    _apply_contact_damage(body)

func _on_area_body_exited(body: Node2D) -> void:
    bodies_inside.erase(body)
```

Alternatively, use a `Timer`-gated cooldown per target.

**Detection:** Suicider kills player instantly on first touch instead of dealing a single hit. Log shows many rapid `body_entered` calls from the same body.

---

### Pitfall M-4: Wave Completion Detected Before Deferred Frees Complete

**What goes wrong:** Wave completion is checked by counting enemy children or reading an `alive_count` integer. When an enemy dies, `queue_free()` is deferred to end-of-frame, so a check immediately after the signal fires still sees the dead enemy as present. The wave is incorrectly not marked complete.

**Why it happens:** `queue_free()` removes the node from the scene tree at the end of the frame, not immediately. `get_child_count()` and `get_children()` still include the node within the same frame.

**Consequences:** Wave never ends. Next wave never spawns. Or: alive_count goes negative if decremented twice (signal fired twice due to double-free).

**Prevention:** Decrement a counter when the enemy calls `die()` and guard with `dying` check in `Body` (already present). Use `call_deferred` for the wave-complete check:

```gdscript
# In WaveSpawner
func _on_enemy_died() -> void:
    alive_count -= 1
    call_deferred("_check_wave_complete")

func _check_wave_complete() -> void:
    if alive_count <= 0:
        _start_next_wave()
```

Do not rely on `get_children()` or `get_child_count()` as the source of truth for alive enemies.

**Detection:** Wave completion never triggers in testing even after all enemies visually disappear.

---

### Pitfall M-5: Enemies Spawned Inside Asteroids or Each Other

**What goes wrong:** Enemies spawn at a random position that overlaps an existing `RigidBody2D` asteroid or another enemy. On the next physics step, the engine resolves the overlap with a large separation impulse, launching the enemy at extreme velocity. The enemy is immediately thrown into FLEEING or EVADING with no meaningful AI.

**Why it happens:** `add_child` + deferred physics means the collision check does not occur until the first physics step after spawn. There is no built-in safe-spawn validation in Godot.

**Consequences:** Enemies launched off-screen on spawn. Player sees enemies teleport away. FLEEING triggers immediately with no prior player contact.

**Prevention:** Spawn from the edge of the visible area (outside minimum radius, as `world.gd` does for asteroids with `MIN_RANGE = 4000`). Use a minimum separation radius between spawn candidates. Optionally: spawn with `collision_layer = 0` for the first 0.1 seconds to let the node settle, then re-enable collision.

Reference the existing asteroid spawner pattern:
```gdscript
asteroid.position = Vector2.from_angle(randf() * 2*PI) * randf_range(MIN_RANGE, MAX_RANGE)
```
Apply the same approach to enemies — spawn beyond the dense asteroid belt, not inside it.

**Detection:** Enemies have extreme `linear_velocity` immediately after spawn. State machine enters FLEEING on first tick.

---

## Minor Pitfalls

---

### Pitfall m-1: `_physics_process` Accumulator-Based Fire Rate Drifts Under Load

**What goes wrong:** Using a `float` accumulator in `_physics_process` to track fire cooldown (`accumulator += delta; if accumulator >= rate: fire()`) is framerate-sensitive if `delta` spikes. Under load (many enemies + asteroids), fire rate drifts and enemies fire slower than intended.

**Prevention:** Use a `Timer` node child with `one_shot = true`, same as `MountableWeapon.shot_timer`. This is already the established pattern in the codebase and keeps behavior consistent. Create it in `_ready()`, not every fire call.

---

### Pitfall m-2: Rotation Computed With `angle_to` Causes Spinning Past Target

**What goes wrong:** Enemies that rotate toward the player using `rotation = angle_to_point(player_position)` directly set rotation each frame, bypassing angular physics. The enemy teleports its facing instead of rotating, and the angular physics state is inconsistent.

**Prevention:** Use `apply_torque()` or set `angular_velocity` in `_integrate_forces` to rotate smoothly within the physics simulation. For enemies that should snap-aim (Sniper), set `rotation` only once when entering the FIGHTING state, not every frame.

---

### Pitfall m-3: MountableBody.Action Enum Not Extended for Enemy-Only Actions

**What goes wrong:** If enemy fire is implemented with new string commands rather than extending the `MountableBody.Action` enum, the v1.0 QUA-01 improvement (typed constants instead of raw strings) is partially undone. Silent mismatches re-enter the codebase.

**Prevention:** If `EnemyShip` needs custom actions (e.g., `SELF_DESTRUCT`), add them to the `MountableBody.Action` enum, or define a local `EnemyShip.Action` enum. Do not use raw strings for any action dispatch.

---

### Pitfall m-4: `find_children` Called in Enemy AI Tick

**What goes wrong:** An `EnemyShip` calls `find_children("*", "MountPoint")` or similar inside `_physics_process` or the state tick to locate its barrel or detection nodes. This was fixed in v1.0 (QUA-02) for weapons; it is equally expensive for enemies.

**Prevention:** Cache all child node references in `_ready()` using `@onready` or explicit assignment. Never call `find_children` in any per-frame method.

---

### Pitfall m-5: `get_tree().create_timer` Used in `die()` With a `delay` — Enemy Still Runs AI During Delay

**What goes wrong:** `Body.die(delay)` already has an `await get_tree().create_timer(delay).timeout` before setting `dying = true`. If an enemy's AI tick fires during this delay window (between die being called with a delay and `dying` being set), the enemy continues to act.

**Why it happens:** `dying` is set *after* the await in `Body.die()`. The guard in Pitfall C-1 only fires after `dying = true`.

**Prevention:** Either don't use `die(delay)` for enemies (call `die(0.0)` directly), or set `dying = true` before the delay await in any `EnemyShip` override:

```gdscript
func die(delay: float = 0.0) -> void:
    dying = true   # guard AI immediately
    super(delay)
```

This is safe because `Body.die()` already has an `if dying: return` guard at entry.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| EnemyShip base class + state machine skeleton | M-1 (oscillating transitions), C-1 (no dying guard) | Add `dying` guard and hysteresis constants before writing any concrete enemy |
| Beeliner / Suicider (direct charge) | C-2 (velocity assignment), M-3 (contact signal spam) | Use `apply_force` only; implement bodies_inside tracking for Suicider |
| Flanker / Sniper (ranged, distance-keeping) | M-2 (orphaned timer on death), C-3 (layer mismatch on detection area) | Use Timer node child for state delays; verify detection area masks against layer table |
| Swarmer (group behavior) | M-4 (wave completion race), M-5 (spawn overlap) | Counter-based alive tracking; spawn from outer radius |
| Wave spawner | M-4 (completion detection), M-5 (spawn inside geometry), C-4 (spawn_parent not propagated) | `call_deferred` check, outer-radius spawning, propagate spawn_parent in wave spawner |
| Enemy fire (simplified) | C-4 (spawn_parent missing), m-3 (raw strings) | Follow `MountableWeapon.fire()` pattern exactly for bullet instantiation |
| All enemies | m-4 (find_children in tick), m-1 (accumulator drift) | @onready cache in _ready(); Timer node for fire rate |

---

## Sources

- Gravity Ace devlog — drone AI in a physics-based space shooter: https://gravityace.com/devlog/drone-ai/
- Godot 4 official — RigidBody2D: https://docs.godotengine.org/en/4.4/classes/class_rigidbody2d.html
- Godot forums — clamping top speed causing jitter: https://forum.godotengine.org/t/clamp-top-speed-giving-a-jittery-look/40420
- Godot forums — homing RigidBody2D velocity compensation: https://forum.godotengine.org/t/compensating-for-linear-velocity-in-a-homing-rigidbody2d/50508
- Godot issue — Area2D body_entered mask bit requirement: https://github.com/godotengine/godot/issues/33129
- Godot forums — queue_free null reference in collision callback: https://forum.godotengine.org/t/attempt-to-call-function-queue-free-in-base-previously-freed-instance-on-a-null-instance-but-why/18998
- Godot forums — enemies spawning on top of each other: https://forum.godotengine.org/t/how-can-i-handling-enemies-spawning-on-top-of-each-other/19716
- Codebase inspection: `components/body.gd`, `components/mountable-weapon.gd`, `components/ship.gd`, `components/mountable-body.gd`, `components/mount-point.gd`, `world.gd`
