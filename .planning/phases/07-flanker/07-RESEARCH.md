# Phase 07: Flanker - Research

**Researched:** 2026-04-12
**Domain:** Orbital AI steering — tangential + radial force control on RigidBody2D, GDScript state machine
**Confidence:** HIGH (formula derived from first principles + verified against Godot source; patterns verified from codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Attack burst (FIGHTING state)**
- D-01: Rapid salvo — multiple bullets in quick succession (~4–6 bullets at ~0.2–0.3s intervals) aimed straight ahead from the barrel. Not a shotgun spread.
- D-02: Fire driven by `_fire_timer` running continuously in FIGHTING. Each timeout fires one bullet. Short interval gives rapid-fire feel.
- D-03: New `flanker-bullet.tscn` — structural copy of `sniper-bullet.tscn`. At `prefabs/enemies/flanker/flanker-bullet.tscn`. No sprite. Fixed `Damage.energy` (ENM-06).
- D-04: Bullet spawning: `spawn_parent.add_child(bullet)` at `$Barrel.global_position` (ENM-05).

**FIGHTING exit**
- D-05: Range-based exit. Stay FIGHTING while player within `return_range`; transition to LURKING when distance > `return_range`.
- D-06: `return_range > fight_range` — hysteresis prevents oscillation at boundary.
- D-07: No FLEEING state. Flanker re-orbits when player escapes, does not flee on its own.
- D-08: Fire timer stops on `_exit_state(FIGHTING)`, starts on `_enter_state(FIGHTING)`.

**LURKING -> FIGHTING trigger**
- D-09: Distance-based: transition when Flanker is within `fight_range` during orbit.
- D-10: No separate attack timer — natural orbit drift creates the attack cycle.

**State machine**
- D-11: States: IDLING -> SEEKING -> LURKING -> FIGHTING -> LURKING (cycle).
- D-12: IDLING -> SEEKING: detection area `body_entered` when player enters detection radius.
- D-13: SEEKING -> LURKING: when Flanker closes to `orbit_entry_range`.
- D-14: LURKING -> FIGHTING: when distance < `fight_range` during orbit.
- D-15: FIGHTING -> LURKING: when distance > `return_range`.
- D-16: No FLEEING state.

**Orbit mechanics (LURKING state)**
- D-17: Tangential steering force + radius correction. Tangential keeps Flanker circling; radial corrects drift.
- D-18: `orbit_direction` = `1.0` or `-1.0` randomized at `_ready()` (50/50). Determines CW vs CCW.
- D-19: `orbit_radius` is `@export var` multiplied by `randf_range(0.8, 1.3)` in `_ready()`.
- D-20: No firing in LURKING.

**Scene / loot**
- D-21: `flanker.tscn` inherits `base-enemy-ship.tscn`. Override `@export` defaults and FireTimer config only.
- D-22: No picker Area2D (ENM-15).
- D-23: Loot drop: coins + ammo following Beeliner/Sniper pattern. Exact weights at Claude's discretion.
- D-24: `die()` override: stop fire timer, call `_ammo_dropper.drop()`, then `super(delay)`.

### Claude's Discretion

- Exact values for `orbit_radius` default, `orbit_entry_range`, `fight_range`, `return_range`
- Exact fire timer interval (~0.2–0.3s)
- Exact bullet speed and `Damage.energy`
- Tangential steering force formula and radius correction magnitude
- Loot drop weights and counts

### Deferred Ideas (OUT OF SCOPE)

- Flanker sprite (asset not yet provided)
- Escape/evade if player enters tight range
- Group coordination between multiple Flankers (v2.1+)

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENM-09 | Flanker orbits player in LURKING state using tangential steering force + radius correction before entering FIGHTING | Orbital force formula derived; tangential + radial decomposition documented with exact GDScript code |

</phase_requirements>

---

## Summary

The Flanker requires one genuinely novel mechanic that the Beeliner and Sniper do not have: orbital motion via physics forces. Every other aspect — state machine wiring, fire timer, bullet spawning, loot, scene inheritance — follows patterns already established and verified in the codebase.

The core technical challenge is computing a steering force that (a) drives the Flanker tangentially around the player (perpendicular to the toward-player vector) and (b) applies a corrective radial force to keep the orbit radius from spiraling in or out. Both forces are applied via `apply_central_force` each physics frame in `_tick_state`, matching ENM-03.

The formula is derivable from first principles using Godot's `Vector2.orthogonal()` built-in (`Vector2(y, -x)` in source), which returns a vector perpendicular to the input. The radius correction is a simple proportional force: `(current_dist - orbit_radius) * correction_strength` in the away or toward direction. No external library is needed; no hand-rolling of complex math.

**Primary recommendation:** Implement orbit in `_tick_state` LURKING branch using tangential force + proportional radial correction. Tune `orbit_correction_strength` in the inspector — it is the single most important parameter for orbit stability. Set `return_range > fight_range` (D-06 hysteresis) and verify it holds before shipping.

---

## Standard Stack

No external libraries. Everything is native Godot 4.6.2 GDScript + built-in physics.

### Core Patterns Used

| Pattern | Source | Purpose |
|---------|--------|---------|
| `apply_central_force()` | `EnemyShip.steer_toward()` [VERIFIED: codebase] | All enemy movement — never direct velocity assignment |
| `_integrate_forces()` with `limit_length(max_speed)` | `EnemyShip._integrate_forces()` [VERIFIED: codebase] | Speed cap — inherited automatically |
| `Timer` node + `timeout` signal | `Beeliner._fire_timer`, `Sniper._fire_timer` [VERIFIED: codebase] | Fire loop control |
| `spawn_parent.add_child(bullet)` | `Beeliner._fire()` [VERIFIED: codebase] | ENM-05 bullet spawning |
| `randf_range()` in `_ready()` | `Beeliner._ready()` [VERIFIED: codebase] | Per-instance variation |
| `Vector2.orthogonal()` | Godot source `vector2.h` [VERIFIED: GitHub] | Perpendicular vector for tangential force |

---

## Architecture Patterns

### Recommended File Structure

```
components/
  flanker.gd                         # Flanker class script
prefabs/enemies/
  flanker/
    flanker.tscn                     # inherits base-enemy-ship.tscn
    flanker-bullet.tscn              # structural copy of sniper-bullet.tscn
```

### Pattern 1: LURKING Orbital Tick

The orbit force is computed each `_tick_state` call when in LURKING state. Two force components:

1. **Tangential force** — perpendicular to the toward-player vector, scaled by `thrust` and `orbit_direction`
2. **Radial correction force** — along the toward-player or away-from-player axis, magnitude proportional to distance error

```gdscript
# Source: derived from first principles + Godot Vector2.orthogonal() docs
# Applied inside _tick_state() LURKING branch

func _tick_state(delta: float) -> void:
    if not is_instance_valid(_target):
        _target = null
        _change_state(State.IDLING)
        return

    var to_target: Vector2 = _target.global_position - global_position
    var dist: float = to_target.length()

    match current_state:
        State.SEEKING:
            look_at(_target.global_position)
            if dist < orbit_entry_range:
                _change_state(State.LURKING)
            else:
                steer_toward(_target.global_position)

        State.LURKING:
            # Tangential component: perpendicular to toward-player, scaled by orbit_direction
            # Vector2.orthogonal() returns Vector2(y, -x) — 90 degrees, magnitude preserved
            var toward_norm: Vector2 = to_target / dist  # normalized without extra call
            var tangential: Vector2 = toward_norm.orthogonal() * orbit_direction

            # Radial correction: push toward orbit_radius
            # Positive error = too far out -> apply toward force; negative = too close -> apply away force
            var radius_error: float = dist - orbit_radius
            var radial: Vector2 = toward_norm * radius_error * orbit_correction_strength

            apply_central_force((tangential + radial) * thrust)

            # Aim tangentially so the barrel faces the direction of travel
            look_at(global_position + tangential)

            # State transition: attack when close enough
            if dist < fight_range:
                _change_state(State.FIGHTING)

        State.FIGHTING:
            if not is_instance_valid(_target):
                _change_state(State.LURKING)
                return
            look_at(_target.global_position)
            steer_toward(_target.global_position)
            if dist > return_range:
                _change_state(State.LURKING)
```

**Key formula breakdown:**
- `to_target / dist` — normalized without a second `length()` call (micro-optimization, avoids two sqrt calls)
- `toward_norm.orthogonal()` — `Vector2(y, -x)`, 90 degrees CCW in standard math; visual direction depends on orbit_direction sign
- `orbit_direction * thrust` — flipping sign reverses CW vs CCW
- `radius_error * orbit_correction_strength` — proportional controller: the further off-radius, the stronger the correction
- Radial correction is NOT normalized — it IS proportional. A smaller magnitude constant keeps it gentle.

### Pattern 2: look_at During Orbit

**Decision:** Aim `look_at(global_position + tangential)` so the barrel faces the direction of travel, not the player. This gives a natural visual appearance (Flanker appears to strafe). On transition to FIGHTING, `look_at(_target.global_position)` overrides immediately so bullets fire toward the player.

This is a departure from Beeliner/Sniper, which always `look_at(_target)`. It is intentional for the Flanker's visual identity.

### Pattern 3: Fire Timer (FIGHTING state)

Identical pattern to Beeliner, minus the spread angles. Single bullet per timeout.

```gdscript
# Source: beeliner.gd lines 34-40 [VERIFIED: codebase]
func _enter_state(new_state: State) -> void:
    if new_state == State.FIGHTING:
        _fire()           # fire immediately on entry
        _fire_timer.start()

func _exit_state(old_state: State) -> void:
    if old_state == State.FIGHTING:
        _fire_timer.stop()

func _on_fire_timer_timeout() -> void:
    if dying or current_state != State.FIGHTING:
        return
    _fire()
```

### Pattern 4: Range-Based State Transitions (Sniper reference)

```gdscript
# Source: sniper.gd lines 43-82 [VERIFIED: codebase]
# Pattern for checking distance and transitioning states in _tick_state

var dist := global_position.distance_to(_target.global_position)
# ... use dist for all comparisons
```

In the Flanker, `dist` is already computed as `to_target.length()` for the orbital force calc — reuse it for state transition checks. No extra `distance_to()` call needed.

### Pattern 5: body_exited for Target Reset (SEEKING only)

The Sniper established this pattern — only clear `_target` in SEEKING, not in other states:

```gdscript
# Source: sniper.gd lines 36-40 [VERIFIED: codebase]
func _on_detection_area_body_exited(body: Node2D) -> void:
    if body == _target and current_state == State.SEEKING:
        _target = null
        _change_state(State.IDLING)
```

The Flanker should use the same pattern. If the player leaves detection area while Flanker is LURKING or FIGHTING, the `is_instance_valid(_target)` guard in `_tick_state` handles cleanup gracefully.

### Pattern 6: die() Override

```gdscript
# Source: beeliner.gd lines 73-78 [VERIFIED: codebase]
func die(delay: float = 0.0) -> void:
    if dying:
        return
    _fire_timer.stop()
    _ammo_dropper.drop()
    super(delay)
```

Flanker identical — stops fire timer, drops ammo, calls super.

### Pattern 7: Bullet Spawning

```gdscript
# Source: beeliner.gd lines 51-66 [VERIFIED: codebase]
func _fire() -> void:
    if dying:
        return
    var bullet := _bullet_scene.instantiate() as RigidBody2D
    var fire_dir := Vector2.from_angle(global_rotation)
    bullet.rotation = global_rotation
    bullet.linear_velocity = fire_dir * bullet_speed
    if spawn_parent:
        spawn_parent.add_child(bullet)
        bullet.global_position = global_position + fire_dir * 350.0
    else:
        push_warning("Flanker: spawn_parent not set")
```

Flanker fires single bullet, no spread. Use `$Barrel.global_position` like Sniper for barrel offset (avoids hardcoded `350.0`):

```gdscript
bullet.global_position = _barrel.global_position
```

### Pattern 8: Scene Inheritance + Collision Layers

From `sniper.tscn` and `beeliner.tscn` [VERIFIED: codebase]:
- Root `RigidBody2D`: `collision_layer = 1` (Ship layer), `collision_mask = 3` (Ship + Weapons), `gravity_scale = 0.0`, `can_sleep = false`
- `DetectionArea`: `collision_layer = 0`, `collision_mask = 1` (detects Ship)
- `HitBox`: `collision_layer = 0`, `collision_mask = 4` (hit by Bullets layer)
- `FireTimer`: `one_shot = false`, `autostart = false`

Flanker bullet follows sniper-bullet.tscn pattern:
- `collision_layer = 256` (bit 9? — wait, let me verify)

Actually checking sniper-bullet.tscn [VERIFIED: codebase]: `collision_layer = 256`, `collision_mask = 1`. Layer 256 = bit 9. But the physics layer table in world.gd says Bullets = layer 3. The `collision_layer` in the .tscn file uses bitmask notation where layer 3 = bit position 3 = integer value... let me check the actual value.

**Note on collision layer encoding:** In the scene files, `collision_layer = 256` for sniper-bullet likely means bit 9 (0-indexed), not layer 3. The comment in `enemy-ship.gd` says "Bullets=3" referring to 1-indexed layer numbers. In Godot, layer N (1-indexed) = bit (N-1), so layer 3 = bit 2 = integer 4. However, the sniper-bullet has `collision_layer = 256 = bit 9`. This is inconsistent — the sniper bullet uses whatever layer was set in the editor. **The flanker-bullet.tscn should copy sniper-bullet.tscn exactly**, so set `collision_layer = 256`, `collision_mask = 1` to match.

### Anti-Patterns to Avoid

- **Assigning `linear_velocity` directly**: forbidden by ENM-03. All movement via `apply_central_force`.
- **Using `position =` or `global_position =` to "snap" orbit**: forbidden. Position assignment bypasses physics.
- **Firing in LURKING**: D-20 says no. Only fire in FIGHTING.
- **Using `_integrate_forces()` for orbit logic**: this is for speed clamping only. Orbit forces go in `_tick_state`.
- **Checking `current_state != State.LURKING` in _on_detection_area_body_exited**: follow the Sniper pattern — only clear target in SEEKING. Other states have own exit logic.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Perpendicular vector | Manual `Vector2(-v.y, v.x)` formula | `vector.orthogonal()` | Built-in, readable, handles magnitude automatically |
| Speed limiting | Per-frame velocity clamp in tick | `_integrate_forces` with `limit_length(max_speed)` | Already in EnemyShip base, inherited automatically |
| Loot drop randomization | Custom weighted random | `ItemDropper.roll()` | Already implemented, used by Beeliner and Sniper |
| Bullet scene structure | New scene from scratch | Copy `sniper-bullet.tscn` | All nodes, layers, script, damage resource already configured |
| Fire rate control | Frame counter or time accumulation | `Timer` node + `timeout` signal | Established pattern; decoupled from physics frame rate |
| Base state machine hooks | Reimplementing _change_state | Call `_change_state()` from base | Already handles exit/enter/print/queue_redraw |

**Key insight:** The orbit force is the only novel code. Everything else is copy-paste + minor modification from Beeliner or Sniper.

---

## Common Pitfalls

### Pitfall 1: Spiral Decay from Linear Damping

**What goes wrong:** The orbit gradually spirals inward over time, and the Flanker ends up circling much closer than `orbit_radius`.

**Why it happens:** Godot's RigidBody2D has a `linear_damp` property (default value exists in project settings). Even small damping bleeds tangential velocity every frame, reducing orbital speed. With less speed, the centripetal balance shifts and the orbit decays inward.

**How to avoid:** Set `linear_damp = 0.0` on the Flanker's RigidBody2D in the scene file. The orbit correction force compensates for any drift. Alternatively, verify the project's default linear damp is already near zero (space game setting suggests it may be).

**Warning signs:** Orbit looks fine for 2–3 seconds then drifts inside `fight_range` and triggers permanent FIGHTING without returning to orbit. Orbit radius visually shrinks over time.

### Pitfall 2: LURKING->FIGHTING->LURKING Oscillation

**What goes wrong:** The Flanker rapidly flickers between LURKING and FIGHTING because `dist` hovers near `fight_range`.

**Why it happens:** The orbit force keeps the Flanker close to `orbit_radius`. If `orbit_radius ~ fight_range`, the Flanker spends every tick exactly on the transition boundary.

**How to avoid:** Ensure `orbit_radius > fight_range` by a meaningful margin (e.g., `orbit_radius = 7000`, `fight_range = 5000`). The hysteresis defined by D-06 (`return_range > fight_range`) handles the FIGHTING->LURKING direction. The LURKING->FIGHTING direction is naturally protected by the orbit radius gap.

**Warning signs:** State label flickers LURKING<->FIGHTING rapidly on first spawn. `print` logs show multiple state changes per second.

### Pitfall 3: Orbit Correction Strength Too High (Overshoot Oscillation)

**What goes wrong:** The Flanker oscillates radially — bouncing in and out of the orbit radius — instead of settling at a stable distance.

**Why it happens:** `orbit_correction_strength` acts as a proportional controller gain. Too high = the correction force overshoots, creating oscillation. This is the classic P-controller instability problem.

**How to avoid:** Start with a low correction strength (e.g., `0.15`) and increase until the orbit looks stable. If oscillation appears, halve the value. The correction does NOT need to be a D-term (derivative) controller — proportional-only works fine at typical game speeds.

**Warning signs:** Flanker moves in and out radially while also orbiting, creating a "wobbly" spiral rather than a circle. Oscillation period is consistent (not random).

### Pitfall 4: Max Speed Clamping Prevents Orbit Closure

**What goes wrong:** The Flanker never actually reaches the player because `max_speed` is too low relative to the orbit's centripetal requirements.

**Why it happens:** In SEEKING, `steer_toward` drives the Flanker to `orbit_entry_range`. But if `max_speed` is set correctly for orbital motion (slower = more stable orbit) it may be too slow to close to `orbit_entry_range` from a spawner far away.

**How to avoid:** Use separate speed profiles: the inherited `max_speed` is fine for LURKING orbit. The SEEKING approach can use a higher thrust multiplier temporarily (or just ensure max_speed is high enough to close range in reasonable time). Beeliner uses `max_speed = 2000.0`, Sniper uses `max_speed = 1500.0` — Flanker should be in this range.

**Warning signs:** Flanker stays in SEEKING forever and never transitions to LURKING. Debug draw shows it far from the player with no progress.

### Pitfall 5: `look_at` During LURKING Points Barrel at Player

**What goes wrong:** If you call `look_at(_target.global_position)` in LURKING (copy-pasted from Beeliner), the Flanker always faces the player — and if the Flanker triggers a fire at that moment (e.g., a stray timer call), bullets will hit the player unexpectedly.

**Why it happens:** The Beeliner `look_at` pattern is correct for SEEKING/FIGHTING but wrong for LURKING where we want the ship facing its direction of travel.

**How to avoid:** In LURKING, use `look_at(global_position + tangential)` — face the direction of travel, not the player. Switch to `look_at(_target.global_position)` on `_enter_state(FIGHTING)`.

**Warning signs:** Flanker in LURKING state rotates continuously to track the player (yellow arrow indicator from `_draw` always points at player instead of orbiting).

### Pitfall 6: Clearing _target in Wrong States

**What goes wrong:** `_target` is set to null while in LURKING or FIGHTING, causing the Flanker to drop to IDLING mid-combat.

**Why it happens:** Copy-pasting the detection_area `body_exited` handler without the SEEKING guard.

**How to avoid:** Exactly follow the Sniper pattern — only clear `_target` in `body_exited` if `current_state == State.SEEKING`. In all other states, the `is_instance_valid(_target)` check in `_tick_state` provides a safe fallback.

**Warning signs:** Flanker in orbit suddenly snaps to IDLING when the player moves near the edge of the detection area.

### Pitfall 7: Fire Timer Misfires After State Exit

**What goes wrong:** The Flanker fires bullets while in LURKING because the fire timer timeout fires after `_exit_state(FIGHTING)`.

**Why it happens:** Timer is still running for one more cycle after `stop()` was called.

**How to avoid:** The guard in `_on_fire_timer_timeout()` — `if dying or current_state != State.FIGHTING: return` — is the authoritative safety check, matching Beeliner and Sniper. Always include this guard.

**Warning signs:** A bullet appears from the Flanker immediately after it transitions back to LURKING.

---

## Code Examples

### Complete Tangential Orbit Formula (Annotated)

```gdscript
# Source: derived from Vector2.orthogonal() Godot source (vector2.h) + first principles
# [VERIFIED: GitHub godotengine/godot master, vector2.h]
#
# In LURKING _tick_state branch:

var to_target: Vector2 = _target.global_position - global_position
var dist: float = to_target.length()

# Guard against zero-distance degenerate case
if dist < 1.0:
    return

var toward_norm: Vector2 = to_target / dist

# TANGENTIAL COMPONENT
# orthogonal() = Vector2(y, -x) -- 90 degrees, same magnitude as input
# orbit_direction (1.0 or -1.0) controls CW vs CCW
var tangential: Vector2 = toward_norm.orthogonal() * orbit_direction

# RADIAL CORRECTION COMPONENT
# radius_error > 0: Flanker is too far out -> push toward player
# radius_error < 0: Flanker is too close in -> push away from player
# orbit_correction_strength ~ 0.1-0.3 (tune in inspector)
var radius_error: float = dist - orbit_radius
var radial: Vector2 = toward_norm * radius_error * orbit_correction_strength

# Apply combined force -- both components contribute to one force vector
apply_central_force((tangential + radial) * thrust)

# Face the direction of travel, not the player
look_at(global_position + tangential)
```

### Export Variables Declaration

```gdscript
# Source: pattern from beeliner.gd + sniper.gd [VERIFIED: codebase]
# All tunable values as exports for inspector adjustment

@export var fight_range: float = 5000.0
@export var return_range: float = 8000.0       # MUST be > fight_range (D-06)
@export var orbit_entry_range: float = 9000.0  # MUST be > return_range
@export var orbit_radius: float = 7000.0       # MUST be > fight_range
@export var orbit_correction_strength: float = 0.15
@export var bullet_speed: float = 5000.0

var orbit_direction: float = 1.0  # set in _ready()
```

### _ready() with Per-Instance Randomization

```gdscript
# Source: beeliner.gd lines 15-19 [VERIFIED: codebase]
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    orbit_radius *= randf_range(0.8, 1.3)   # D-19
    orbit_direction = 1.0 if randf() > 0.5 else -1.0  # D-18
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
    detection_area.body_exited.connect(_on_detection_area_body_exited)
```

### Bullet Spawning (Single, No Spread)

```gdscript
# Source: sniper.gd lines 109-120 [VERIFIED: codebase]
# Flanker variant: single bullet, uses _barrel reference like Sniper
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
        push_warning("Flanker: spawn_parent not set")
```

---

## Suggested Tuning Values (Claude's Discretion)

These are starting points for playtesting. All are `@export` vars adjustable without recompile.

| Parameter | Suggested Default | Rationale |
|-----------|------------------|-----------|
| `orbit_radius` | 7000.0 | Between Beeliner `fight_range=8000` and Sniper `comfort_range=10000`; close enough to be a threat |
| `orbit_entry_range` | 9500.0 | > orbit_radius so transition happens before reaching desired orbit |
| `fight_range` | 4500.0 | Significantly less than orbit_radius — creates natural attack window |
| `return_range` | 7500.0 | > fight_range hysteresis gap; ensures FIGHTING->LURKING transition has buffer |
| `orbit_correction_strength` | 0.15 | Start low; increase if orbit drifts, decrease if oscillation appears |
| `bullet_speed` | 5500.0 | Faster than Sniper's dramatic slow shots; Flanker is close-range rapid fire |
| `Damage.energy` | 5.0 | Lower per-shot than Sniper (20.0) since Flanker fires more bullets |
| `_fire_timer.wait_time` | 0.25 | Within the specified ~0.2-0.3s range (D-01) |
| `max_speed` | 2000.0 | Matches Beeliner; fast enough to close to orbit, stable enough to orbit |
| `thrust` | 1500.0 | Matches Beeliner baseline |
| `detection_radius` | 10000.0 | Matches existing enemies |

**Validation sequence:**
1. Does the Flanker visibly circle at roughly `orbit_radius`? -> orbit_correction_strength is right
2. Does the orbit stay stable for 10+ seconds without spiraling? -> linear_damp is 0.0
3. Does fight_range trigger reliably without flickering? -> gap between orbit_radius and fight_range is adequate
4. Do rapid bullets feel like a strafing run? -> fire timer interval and bullet_speed are correct

---

## Orbit Stability Analysis

**The physics:** Tangential force alone produces an ever-tightening or expanding spiral — it does not produce a stable orbit. The radius correction force is what anchors the orbit at the desired radius. Together, the two forces are a simplified polar coordinate controller.

**Stability condition:** The orbit is stable when the tangential force provides enough angular momentum to avoid collapse into the center, and the radial correction force is strong enough to resist drift but not so strong it causes overshoot.

**Does it need a damping term?** In a pure physics simulation, yes — a PD controller (proportional + derivative) would give better stability. In this game context, no: the `limit_length(max_speed)` clamp in `_integrate_forces` acts as an implicit damper. When correction forces build up excessive velocity, the speed cap absorbs the excess. This gives the orbit natural stability without a D-term.

**Does it need dampening at state transitions?** The transition LURKING->FIGHTING->LURKING can cause the Flanker to carry high velocity from the attack run back into the orbit. This is fine — the radial correction force will push it back toward orbit_radius, and the tangential force will re-establish circular motion within a few seconds. No explicit velocity reset needed (which would require direct `linear_velocity` assignment — forbidden by ENM-03).

**[ASSUMED]** The exact tuning of `orbit_correction_strength` will require playtesting. The suggested 0.15 is a starting point based on the typical scale of forces in this codebase (thrust = 1500, orbit_radius = 7000). This cannot be verified analytically without running the simulation.

---

## Environment Availability

Step 2.6: SKIPPED — phase is code/configuration only. No external tools beyond Godot 4.6.2 (already running, verified by prior phases in this milestone).

---

## Runtime State Inventory

Step 2.5: SKIPPED — this is a greenfield enemy type phase, not a rename/refactor/migration phase. No runtime state to inventory.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `orbit_correction_strength = 0.15` produces stable orbit at the suggested scale values | Suggested Tuning Values | Easy to fix — export var, adjust in inspector during UAT |
| A2 | `linear_damp = 0.0` on the RigidBody2D will prevent spiral decay (or project default is already near zero) | Pitfall 1 | If project default damp is non-zero, orbit will decay; fix by setting field explicitly in flanker.tscn |
| A3 | `look_at(global_position + tangential)` gives a visually natural orbit appearance (Flanker faces direction of travel) | Pattern 2 | Could look awkward — easy to change to `look_at(_target)` if preferred, purely cosmetic |
| A4 | `fight_range = 4500.0` and `orbit_radius = 7000.0` create a meaningful orbit-then-attack cycle | Suggested Tuning Values | Gap may be too large (Flanker never attacks) or too small (attacks too often); tunable export vars |
| A5 | The flanker-bullet.tscn `collision_layer = 256` (copied from sniper-bullet.tscn) is the correct physics layer for enemy bullets | Architecture Patterns | If wrong, bullets won't hit player — verify by checking sniper bullet behavior already works |

---

## Open Questions

1. **What is the actual project-default `linear_damp` value?**
   - **RESOLVED (planning phase):** `project.godot` does NOT override Godot's default (`0.0`), but the project actively uses non-zero values in scenes (`ship-bfg-23.tscn` sets `linear_damp = 1.0`). Decision: `flanker.tscn` MUST set `linear_damp = 0.0` explicitly on the root RigidBody2D to prevent orbital spiral decay (Pitfall 1). Implemented in 07-02-PLAN.md Task 1.

2. **Should `look_at` in LURKING aim at direction of travel or at player?**
   - **RESOLVED (planning phase):** Implement as `look_at(global_position + tangential)` per Pattern 2 — direction of travel, not the player. This gives the natural strafing visual for an orbiting ship. Implemented in 07-01-PLAN.md Task 1 LURKING branch.

---

## Sources

### Primary (HIGH confidence)
- `components/enemy-ship.gd` — EnemyShip base class: `steer_toward`, `_integrate_forces`, `State` enum, detection wiring [VERIFIED: codebase]
- `components/beeliner.gd` — Fire timer pattern, `_fire()`, `die()`, `_ready()` randomization [VERIFIED: codebase]
- `components/sniper.gd` — Range-based state transitions, `body_exited` guard pattern [VERIFIED: codebase]
- `prefabs/enemies/sniper/sniper-bullet.tscn` — Bullet scene template (collision layers, Damage resource, life) [VERIFIED: codebase]
- `prefabs/enemies/beeliner/beeliner.tscn` — Scene node structure, collision layer values, FireTimer config [VERIFIED: codebase]
- GitHub: `godotengine/godot/blob/master/core/math/vector2.h` — `Vector2::orthogonal()` returns `Vector2(y, -x)` [VERIFIED: source code]
- GitHub: `godotengine/godot/pull/39685` — `tangent()` renamed to `orthogonal()` in Godot 4 [VERIFIED: PR]

### Secondary (MEDIUM confidence)
- Godot Forum discussion on homing RigidBody2D orbit: perpendicular velocity = orbital motion [CITED: forum.godotengine.org/t/compensating-for-linear-velocity-in-a-homing-rigidbody2d/50508]
- Community search results confirming `Vector2(y, -x)` = CCW perpendicular [CITED: playgama.com/blog/godot/...]

### Tertiary (LOW confidence)
- Suggested default tuning values for `orbit_correction_strength`, `fight_range`, `orbit_radius` — training knowledge, not simulated [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack (patterns): HIGH — all code patterns verified directly from the codebase
- Orbital formula: HIGH — derived from Vector2.orthogonal() source + first principles physics
- Tuning values: LOW — cannot verify without running the simulation; all are @export vars for easy adjustment
- Pitfalls: HIGH — derived from physics reasoning and cross-referenced with Godot forum discussions

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable Godot GDScript API, no moving parts)
