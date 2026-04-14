# Phase 09: Suicider - Research

**Researched:** 2026-04-13
**Domain:** Godot 4 GDScript enemy AI — contact-detonating enemy, Area2D physics signal timing, locked-vector torpedo mechanics
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Lead-in lock — on SEEKING entry, lock target position as a fixed world point (Vector2), steer toward that fixed point for the run duration
- **D-02:** Thrust ramp — multiply steering force by `1.0 + (1.0 - dist / detection_radius)` clamped [1.0, 2.0]
- **D-03:** Re-acquires on long miss — if Suicider reaches/passes locked target without contact, re-enters SEEKING and locks new vector
- **D-04:** ContactArea2D — dedicated Area2D, `collision_layer = 0`, `collision_mask = 1` (Ship layer), radius ~30–35px; connect `body_entered` in suicider.gd
- **D-05:** Do NOT repurpose HitBox for contact detection
- **D-06:** Double-trigger guard — `if dying: return` in signal handler is sufficient; `die()` sets `dying = true` synchronously before queue_free
- **D-07:** Body.death export var mechanism — assign suicider-explosion.tscn as `death` export; Body.die() handles instantiation and positioning automatically
- **D-08:** Create `prefabs/enemies/suicider/suicider-explosion.tscn` — radius ~400–500px, high Damage.energy, high power (strong knockback)
- **D-09:** Speed: faster than Beeliner (max_speed = 2000.0 in beeliner.tscn); exact value at Claude's discretion
- **D-10:** HP: fragile — less than Beeliner (max_health = 30 in beeliner.tscn); exact value at Claude's discretion
- **D-11:** Remove Barrel node — no fire logic needed
- **D-12:** No loot drops — no ItemDropper nodes
- **D-13:** States: IDLING → SEEKING only. No FIGHTING, FLEEING, LURKING
- **D-14:** die() override: stop any timers, then super(delay). No ammo dropper

### Claude's Discretion

- Exact max_speed value (noticeably faster than Beeliner's 2000.0)
- Exact thrust value and ramp formula / clamp range
- Exact re-acquisition trigger logic (dot product or distance-shrinking-to-growing)
- Exact suicider-explosion.tscn values: radius (~400–500), power, attack.energy, attack.kinetic
- HP value (just "less than Beeliner" — Beeliner = 30)
- Per-instance speed variation with randf_range(0.8, 1.2)
- ContactArea2D exact radius

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENM-11 | Suicider — seeks player in SEEKING, triggers existing Explosion component on body_entered contact; no picker node; no fire logic | D-01 through D-14 in CONTEXT.md; Body.death mechanism verified in codebase; ContactArea2D pattern researched |

</phase_requirements>

---

## Summary

The Suicider is the simplest of the five enemy types in terms of code complexity: no fire logic, no loot, no FIGHTING state. Its complexity lives in the **locked-vector torpedo mechanic** (SEEKING locks a fixed world position, not a live target) and the **ContactArea2D detonation path**. The explosion itself is fully handled by the existing `Explosion` component via the `Body.death` export var — zero custom explosion code is needed.

The critical technical question — whether `Body.die()` with direct `spawn_parent.add_child()` and `queue_free()` is safe to call from within an `Area2D.body_entered` signal handler — is **YES with one caveat**: the `Explosion` component itself correctly uses `call_deferred("add_child", area)` when adding its internal `Area2D`, which is the physics-sensitive operation. The outer `spawn_parent.add_child(explosion_node)` in `Body.die()` is a Node2D, not a CollisionObject, so it does not trigger the "Removing a CollisionObject during a physics callback" error. The existing asteroid death + explosion pipeline uses this same path and works in production.

The re-acquisition trigger (D-03) is cleanly implemented with a dot product check: when `linear_velocity.dot(locked_target - global_position) < 0`, the Suicider is moving away from its locked point and has overshot. This is a single-frame check in `_tick_state` with no additional state variables required.

**Primary recommendation:** Two-plan phase — Plan 1: suicider.gd script + suicider-explosion.tscn; Plan 2: suicider.tscn inherited scene + world.gd WaveManager integration + playtest.

---

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `EnemyShip` (components/enemy-ship.gd) | project | Base class with State enum, dying guard, steer_toward, _integrate_forces max_speed clamp | Already implemented in Phase 4; all enemy types extend it |
| `Body.death` export var (components/body.gd) | project | Automatic explosion spawn on any die() call | Used by asteroids and player ship — established pattern, zero extra code needed |
| `Explosion` component (components/explosion.gd) | project | Radius-based area damage + shockwave; handles its own Area2D, particles, audio, self-cleanup | Already exists; suicider-explosion.tscn is a new configuration, not new code |
| `Area2D` (ContactArea2D) | Godot 4.6.2 | Dedicated contact-detection zone, collision_mask=1 (Ship layer) | Separate from HitBox (mask=4, Bullets); clean separation of concerns per D-05 |
| `beeliner.tscn` pattern | project | Inherited scene structure from base-enemy-ship.tscn; Suicider is a simplified Beeliner without Barrel/FireTimer/AmmoDropper | Proven structure across 4 prior enemy types |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `randf_range(0.8, 1.2)` per-instance variation | GDScript built-in | Vary thrust and max_speed per instance | In `_ready()` — established pattern in Beeliner, Flanker, Swarmer |
| `lerp_angle` for rotation | GDScript built-in | Smooth rotation toward locked target during SEEKING | Use same pattern as Swarmer SEEKING: `rotation = lerp_angle(rotation, target_dir.angle(), 5.0 * delta)` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Body.death export var | Manual instantiation in die() override | Body.death is zero boilerplate and already tested; no reason to hand-roll |
| Dedicated ContactArea2D | Repurpose HitBox | Forbidden by D-05; HitBox mask=4 (Bullets only) — mixing concerns causes future bugs |
| Dot product overshoot detection | Distance delta tracking (was_shrinking, now_growing) | Dot product is single-expression, no auxiliary state; distance-delta requires two-frame memory variable |

**Installation:** No new packages. All libraries are already present in project.

---

## Architecture Patterns

### Recommended Project Structure

```
components/
└── suicider.gd                    # New script — extends EnemyShip
prefabs/enemies/suicider/
├── suicider.tscn                  # Inherited from base-enemy-ship.tscn
└── suicider-explosion.tscn        # New scene — configures Explosion component
```

### Pattern 1: Locked-Vector Torpedo (SEEKING state with fixed target)

**What:** On SEEKING entry, snapshot `_locked_target_pos = player.global_position`. Steer toward that Vector2 for the run. Player can dodge by moving sideways. If the Suicider overshoots (dot product goes negative), re-enter SEEKING to re-lock.

**When to use:** Every physics frame while in SEEKING state. The locked position never updates — not the player's live position.

**Example:**
```gdscript
# Source: codebase analysis (beeliner.gd + swarmer.gd patterns adapted)
var _locked_target_pos: Vector2 = Vector2.ZERO

func _enter_state(new_state: State) -> void:
    if new_state == State.SEEKING and _target:
        # D-01: Lock position at detection time — NOT live tracking
        _locked_target_pos = _target.global_position

func _tick_state(delta: float) -> void:
    match current_state:
        State.SEEKING:
            var to_locked := _locked_target_pos - global_position
            var dist := to_locked.length()

            # D-03: Re-acquire if we've passed the locked point (overshoot)
            # dot product < 0 means velocity points away from locked target
            if linear_velocity.length_squared() > 100.0 and linear_velocity.dot(to_locked) < 0.0:
                _enter_state(State.SEEKING)  # Re-lock with fresh target position
                return

            # D-02: Thrust ramp — more force as distance shrinks
            var thrust_mult := clampf(1.0 + (1.0 - dist / detection_radius), 1.0, 2.0)

            var dir := to_locked / dist
            apply_central_force(dir * thrust * thrust_mult)
            # Smooth rotation toward movement direction
            if linear_velocity.length_squared() > 100.0:
                rotation = lerp_angle(rotation, linear_velocity.angle(), 5.0 * delta)
```

**Note on re-acquisition:** Calling `_enter_state(State.SEEKING)` directly (not `_change_state`) avoids the "no change if same state" guard in `_change_state`. This is intentional — re-acquisition re-runs the state entry code with a fresh lock. Alternatively, use a dedicated `_reacquire()` function that just re-snapshots `_locked_target_pos`. The latter is cleaner. [VERIFIED: codebase — `_change_state` has `if new_state == current_state: return` guard at enemy-ship.gd:52]

### Pattern 2: ContactArea2D Detonation

**What:** Dedicated Area2D node with `collision_layer = 0`, `collision_mask = 1` (Ship layer only). Connect `body_entered` in `_ready()`. When a `PlayerShip` body enters → call `die()`. The `dying` flag set synchronously in `die()` prevents re-entrant signal calls.

**When to use:** Only the Suicider uses this. HitBox remains mask=4 (Bullets) unchanged.

**Example:**
```gdscript
# Source: codebase analysis (enemy-ship.gd + beeliner.gd patterns)
@onready var _contact_area: Area2D = $ContactArea

func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    # Physics layers (world.gd):
    # 1=Ship  2=Weapons  3=Bullets  4=Asteroids  5=Explosions  6=Coins  7=Ammo  8=WeaponItem
    _contact_area.set_collision_layer_value(1, false)  # not on Ship layer
    _contact_area.set_collision_mask_value(1, true)     # detects Ship layer

    # Override base class signal handler to store target first
    detection_area.body_entered.connect(_on_detection_area_body_entered)
    _contact_area.body_entered.connect(_on_contact_area_body_entered)

func _on_detection_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip and current_state == State.IDLING:
        _target = body
        _change_state(State.SEEKING)

func _on_contact_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip:
        die()
```

### Pattern 3: Body.death Export Var (explosion delivery)

**What:** Assign `suicider-explosion.tscn` as the `death` export var on the Suicider scene. When `Body.die()` runs (from contact OR bullet damage), it instantiates the PackedScene at `global_position`, sets `spawn_parent`, and calls `add_child`. The Explosion component does the rest: creates its Area2D deferred, waits 0.1s, calls `apply_shockwave()`, then self-destructs.

**When to use:** Always. Do not override this in `suicider.gd`'s `die()`. Just call `super(delay)` after cleanup (no timers to stop — unlike Beeliner/Swarmer there is no FireTimer).

**Example:**
```gdscript
# Source: codebase analysis (body.gd:32-57, beeliner.gd:73-78)
func die(delay: float = 0.0) -> void:
    if dying:
        return
    # No FireTimer, no AmmoDropper — D-11, D-12
    super(delay)
    # Body.die() will: set dying=true, instantiate death scene at global_position,
    # set spawn_parent on it, add_child it, then queue_free self.
```

### Pattern 4: suicider-explosion.tscn configuration

**What:** A new scene using `Explosion` as root script (Node2D). Based on reference values in the existing explosion scenes:

| Explosion | radius | power | attack.energy | attack.kinetic |
|-----------|--------|-------|---------------|----------------|
| asteroid-explosion.tscn | 1000 | 1000 | 0 | 50 |
| ship-bfg-23-explosion.tscn | 3000 | 50000 | 500 | 500 |
| **suicider-explosion.tscn (target)** | **450** | **8000–12000** | **300–400** | **100–200** |

**Rationale:** The suicider explosion should be smaller than asteroid-explosion (radius 1000) but more deadly. ship-bfg-23-explosion (radius 3000, power 50000) is the player's entire ship destruction — suicider should be ~1/6th the radius but concentrated damage. A radius of 450 with power ~10000 and attack.energy ~350 creates a devastating but not world-ending contact hit. [ASSUMED — exact values require playtest calibration]

### Anti-Patterns to Avoid

- **Tracking live player position during charge:** Negates the torpedo/dodge mechanic. The locked position must be a Vector2 snapshot, not `_target.global_position` read every frame.
- **Repurposing HitBox for contact detection:** HitBox mask=4 means it only sees Bullets. The PlayerShip is on layer 1 (Ship). If you change HitBox mask to include layer 1, it will also interfere with bullet damage routing. Use dedicated ContactArea2D per D-05.
- **Calling `_change_state(State.SEEKING)` for re-acquisition:** The guard `if new_state == current_state: return` blocks the re-lock. Use a re-acquire helper that re-snapshots the target position without going through `_change_state`.
- **Calling `super()` before cleanup in `die()` override:** `super()` calls `queue_free()` at the end. Any code after `super()` will run on a freed node. Always call cleanup (stop timers, etc.) before `super(delay)`. [VERIFIED: codebase — body.gd:57 shows queue_free() is the last line of die()]
- **Adding ContactArea2D to base-enemy-ship.tscn:** This node is specific to Suicider only. Add it only in suicider.tscn.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Explosion area damage + knockback | Custom damage loop in die() | `Explosion` component + `Body.death` export | Explosion.gd handles Area2D creation, distance falloff, shockwave impulse, particles, audio, self-cleanup. Already used by asteroids and player ship death. |
| Double-trigger prevention | Monitoring flag toggle, signal disconnect | `dying` flag in base Body class | `dying = true` is set synchronously in `Body.die()` before queue_free. The guard `if dying: return` in every signal handler is sufficient per D-06. |
| Per-instance randomization | Custom seeded RNG | `randf_range(0.8, 1.2)` in `_ready()` | Established pattern in Beeliner, Flanker, Swarmer — consistent with project conventions. |
| Max speed enforcement | Manual velocity clamp | `_integrate_forces` in EnemyShip base | Already implemented in enemy-ship.gd:41: `state.linear_velocity = state.linear_velocity.limit_length(max_speed)` |
| Re-acquisition overshoot check | Two-frame distance delta tracking | Dot product check: `linear_velocity.dot(to_locked) < 0.0` | Single expression, no auxiliary state, geometrically correct. |

**Key insight:** The Suicider is the most minimal enemy type — the simplicity is a feature, not a gap. Resist adding complexity that the other enemy types need but the Suicider doesn't.

---

## Common Pitfalls

### Pitfall 1: `_change_state` re-acquisition guard
**What goes wrong:** Calling `_change_state(State.SEEKING)` to re-acquire the target appears to work but silently does nothing — the guard at enemy-ship.gd:54 returns early when `new_state == current_state`.
**Why it happens:** `_change_state` has an idempotency guard designed to prevent no-op transitions. Re-acquisition while already in SEEKING triggers this guard.
**How to avoid:** Implement a `_reacquire_target()` function that directly re-snapshots `_locked_target_pos = _target.global_position` without going through `_change_state`. Call it when the dot product check fires.
**Warning signs:** Suicider passes the player without re-locking and flies offscreen.

### Pitfall 2: Explosion Area2D collision mask confusion
**What goes wrong:** The Explosion component's internal Area2D has `collision_mask = 4` (Asteroids) and clears masks 1, 2, 3 (see explosion.gd:36–39). This means the explosion damages asteroids but its area detection does NOT detect the PlayerShip (layer 1). However, `apply_damage` is called on `Body` instances found in `get_overlapping_bodies()`, and the PlayerShip IS a Body. The mask setup only affects what bodies the physics engine reports — mask=4 means only bodies on layer 4 (Asteroids) are reported.
**Why it happens:** Reading explosion.gd:36–39 seems to imply player gets no damage, but `apply_shockwave` calls `apply_damage` on any `Body` in overlapping bodies, and the player ship IS a RigidBody2D on layer 1 (Ship). The Area2D mask must include layer 1 to detect the ship.
**How to avoid:** Verify the existing ship-bfg-23-explosion.tscn actually hits the player in the existing game. If it does, the mask setup is already correct. If not, the suicider explosion may need `set_collision_mask_value(1, true)` patched in. [ASSUMED — requires runtime verification; the existing explosion scenes may not currently damage the player via their Area2D]
**Warning signs:** Suicider explodes, particles play, but player takes no damage and receives no knockback.

### Pitfall 3: Node spawn order during physics callback — the "Removing CollisionObject" error
**What goes wrong:** Godot 4 emits the error "Removing a CollisionObject node during a physics callback is not allowed" when a CollisionObject (RigidBody2D, StaticBody2D, CharacterBody2D, Area2D) is freed during a physics step.
**Why it happens:** `body_entered` is fired during the physics step. If `die()` → `queue_free()` is called directly on the Suicider (a RigidBody2D, which IS a CollisionObject), this CAN trigger the warning in some Godot versions.
**How to avoid:** `queue_free()` in Godot 4 is explicitly safe to call from physics callbacks — it queues deletion until after the physics step. The "Removing CollisionObject" error is caused by `free()` (immediate) not `queue_free()` (deferred). `Body.die()` uses `queue_free()` — this is the correct path. [VERIFIED: codebase — body.gd:57 uses queue_free(), not free()]
**Warning signs:** Console error "Removing a CollisionObject node during a physics callback". If seen, check whether any code path calls `free()` instead of `queue_free()`.

### Pitfall 4: Explosion spawned at wrong position
**What goes wrong:** The explosion appears at world origin (0,0) instead of where the Suicider died.
**Why it happens:** `Body.die()` sets `node.global_position = global_position` before `spawn_parent.add_child(node)`. If `spawn_parent` is not set on the Suicider, the explosion node is not added to the scene at all (push_warning fires instead).
**How to avoid:** Ensure `world.gd`'s `setup_spawn_parent()` is called on the Suicider after WaveManager spawns it. WaveManager already sets spawn_parent on spawned enemies — verify this in the WaveManager code.
**Warning signs:** "spawn_parent not set on [name]" warning in console; no explosion visible on death.

### Pitfall 5: ContactArea2D not detecting PlayerShip
**What goes wrong:** Suicider collides with player visually (both RigidBody2D, they push each other) but `_on_contact_area_body_entered` never fires.
**Why it happens:** `collision_mask` not set correctly on ContactArea2D, or the signal was not connected (Godot 4 requires explicit `body_entered.connect()` for areas configured in code, not just in the scene).
**How to avoid:** In `_ready()`, call both `set_collision_layer_value` and `set_collision_mask_value` on `_contact_area` explicitly. Connect `body_entered` signal. Set `monitoring = true` (default is true for Area2D, but verify after inheritance).
**Warning signs:** Suicider passes through player, no explosion triggered, no die() call.

### Pitfall 6: Thrust ramp clamp produces thrust < base thrust
**What goes wrong:** When `dist > detection_radius`, the formula `1.0 + (1.0 - dist/detection_radius)` can return values below 1.0 (e.g., dist=2x detection_radius gives 1.0 + (1.0 - 2.0) = 0.0). Without clampf, the multiplier goes negative, pushing the Suicider away from the target.
**Why it happens:** The ramp formula is only valid within detection range. Outside detection range (which happens momentarily after first detection before the Suicider accelerates inward), `dist` can exceed `detection_radius`.
**How to avoid:** Use `clampf(1.0 + (1.0 - dist / detection_radius), 1.0, 2.0)` exactly. The lower clamp at 1.0 ensures base thrust is always maintained. [VERIFIED: D-02 in CONTEXT.md explicitly specifies clamped to [1.0, 2.0]]

---

## Code Examples

Verified patterns from codebase analysis:

### Full suicider.gd skeleton
```gdscript
# Source: codebase analysis — components/beeliner.gd, components/swarmer.gd patterns
class_name Suicider
extends EnemyShip

var _target: Node2D = null
var _locked_target_pos: Vector2 = Vector2.ZERO

@onready var _contact_area: Area2D = $ContactArea

func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    # Physics layers (world.gd):
    # 1=Ship  2=Weapons  3=Bullets  4=Asteroids  5=Explosions  6=Coins  7=Ammo  8=WeaponItem
    _contact_area.set_collision_layer_value(1, false)  # ContactArea not on Ship layer
    _contact_area.set_collision_mask_value(1, true)     # ContactArea detects Ship layer
    detection_area.body_entered.connect(_on_detection_area_body_entered)
    _contact_area.body_entered.connect(_on_contact_area_body_entered)

func _on_detection_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip and current_state == State.IDLING:
        _target = body
        _change_state(State.SEEKING)

func _on_contact_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip:
        die()

func _enter_state(new_state: State) -> void:
    if new_state == State.SEEKING and is_instance_valid(_target):
        _locked_target_pos = _target.global_position  # D-01: Lock position once

func _tick_state(delta: float) -> void:
    if not is_instance_valid(_target):
        _target = null
        _change_state(State.IDLING)
        return

    match current_state:
        State.SEEKING:
            var to_locked := _locked_target_pos - global_position
            var dist := to_locked.length()
            if dist < 1.0:
                return

            # D-03: Re-acquire if we've overshot (velocity now points away from locked target)
            if linear_velocity.length_squared() > 100.0 and linear_velocity.dot(to_locked) < 0.0:
                _locked_target_pos = _target.global_position  # Re-lock fresh position
                return

            # D-02: Thrust ramp — 1.0x at full detection radius, 2.0x at contact
            var thrust_mult := clampf(1.0 + (1.0 - dist / detection_radius), 1.0, 2.0)
            apply_central_force((to_locked / dist) * thrust * thrust_mult)

            # Smooth rotation toward velocity direction
            if linear_velocity.length_squared() > 100.0:
                rotation = lerp_angle(rotation, linear_velocity.angle(), 5.0 * delta)

func die(delay: float = 0.0) -> void:
    if dying:
        return
    # D-11, D-12: No FireTimer to stop, no drop logic — cleaner than all prior types
    super(delay)
    # Body.die() handles: dying=true, death scene instantiation, queue_free
```

### suicider-explosion.tscn export var values
```
# Source: codebase analysis — asteroid-explosion.tscn (radius=1000, power=1000)
#         and ship-bfg-23-explosion.tscn (radius=3000, power=50000) as reference points
# Suicider explosion: medium radius, high lethality, strong knockback
radius = 450.0          # ~half asteroid explosion, large enough to punish near-misses
time = 2.0              # same as asteroid explosion
power = 10000           # ~10x asteroid, visibly launches player
attack.energy = 350.0   # High energy damage — near-lethal
attack.kinetic = 100.0  # Additional kinetic component
# Particles: same scale/curve as asteroid-explosion.tscn; increase amount to ~500
# Audio: reuse same explosion-1..4 wav pool
```

### ContactArea2D .tscn node definition
```gdscript
# In suicider.tscn — add after HitBox definition
[sub_resource type="CircleShape2D" id="CircleShape2D_contact"]
radius = 330.0  # Slightly larger than collision shape (300px) for reliable detection

[node name="ContactArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 1    # Ship layer — set to 1 here OR via set_collision_mask_value in _ready()
monitoring = true
monitorable = false

[node name="ContactShape" type="CollisionShape2D" parent="ContactArea"]
shape = SubResource("CircleShape2D_contact")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual explosion instantiation in die() | Body.death export var + Explosion component | Phase 4–5 (project architecture) | Zero boilerplate in suicider.gd — assign scene, die() does the rest |
| Direct velocity assignment for clamping | `_integrate_forces` with `limit_length(max_speed)` | Phase 4 (ENM-03) | Physics-correct; no jitter from direct velocity assignment |
| NavigationAgent2D pathfinding | Steering vectors with `apply_central_force` | Phase 4 (out of scope decision) | No nav mesh in open space; simpler and more responsive |

**Deprecated/outdated for this phase:**
- `steer_toward(_target.global_position)`: The Suicider does NOT use live target tracking. Use `steer_toward(_locked_target_pos)` or inline `apply_central_force` with the ramp multiplier.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Explosion component's Area2D mask setup (mask=4 Asteroids only, mask 1/2/3 cleared) means the player ship may NOT currently receive damage from asteroid-explosion or ship-bfg-23-explosion | Common Pitfalls #2 | If wrong and player IS hit by explosion shockwave already, suicider explosion will work as designed. If right, the suicider-explosion scene needs mask=1 added to its Area2D — but that's inside Explosion.initialize() which is not trivially overridable. Needs runtime verification. |
| A2 | suicider-explosion.tscn values (radius=450, power=10000, energy=350, kinetic=100) | Code Examples + Architecture Patterns #4 | Exact values require playtest calibration. Too low = not punishing enough. Too high = instant-kill at any range. Safe to start here and tune. |
| A3 | ContactArea2D collision_mask set to 1 in .tscn AND also via set_collision_mask_value in _ready() is redundant but not harmful | Code Examples | If .tscn sets mask correctly, the _ready() calls are no-ops. Following the established enemy-ship.gd pattern (which also sets masks in _ready()) keeps the code consistent and explicit. |

**Requires runtime verification before locking:**
- A1 is the highest-risk assumption. Before declaring the explosion "works," verify manually that the player ship takes damage and receives knockback when standing within radius of any existing explosion (asteroid death, gravity gun). If not, a fix to Explosion component or to the suicider-explosion scene's Area2D mask is needed.

---

## Open Questions

1. **Does the existing Explosion component actually damage the PlayerShip?**
   - What we know: `Explosion.apply_shockwave()` calls `get_overlapping_bodies()` on its internal Area2D. The Area2D has collision mask 1 cleared (explosion.gd:37: `area.set_collision_mask_value(1, false)`). PlayerShip is on layer 1.
   - What's unclear: With mask 1 cleared, the Area2D should NOT detect RigidBody2D bodies on layer 1. This implies the existing ship-bfg-23-explosion does NOT damage the player via the Explosion component's shockwave path. However, the game is playable, so either (a) player ship damage from explosions is not yet tested, or (b) the physics layer assignment for PlayerShip differs from what's documented.
   - Recommendation: Test in the first playtest: stand next to an asteroid, kill it, observe if the explosion pushes/damages the player. If not, the suicider explosion needs a mask fix: add `set_collision_mask_value(1, true)` in explosion.gd OR create a suicider-specific explosion subclass that overrides `initialize()`. This is **Phase 9 Plan 2** territory — verify in playtest and patch if needed.

2. **Should `_on_detection_area_body_entered` be overridden or shadowed?**
   - What we know: `enemy-ship.gd` defines `_on_detection_area_body_entered` as a standalone function connected in `_ready()`. Beeliner and Swarmer both define their own `_on_detection_area_body_entered` in their scripts, which overrides the connection because `detection_area.body_entered.connect()` is called again in the subclass `_ready()` — this means BOTH the base class handler AND the subclass handler fire.
   - What's unclear: Does the base EnemyShip connect the detection_area signal in its own `_ready()`? Looking at enemy-ship.gd:30 — yes, it does. And Beeliner/Swarmer re-connect in their `_ready()`. This means the signal fires twice: once to the base handler (which only transitions IDLING → SEEKING), and once to the subclass handler (which also sets `_target`). Since the base handler checks `current_state == State.IDLING` and the subclass handler transitions to SEEKING first, the order matters.
   - Recommendation: Follow the exact pattern of Beeliner (beeliner.gd:44–49) — define `_on_detection_area_body_entered` in suicider.gd that sets `_target` AND calls `_change_state(State.SEEKING)`. The base class handler will also fire and attempt to call `_change_state` again, but the idempotency guard blocks it. This is the established pattern.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — this is a pure GDScript/Godot scene phase; all required tools are Godot editor and existing project files).

---

## Security Domain

Security enforcement not applicable to a game project with no network, authentication, or user data handling. Omitted.

---

## Sources

### Primary (HIGH confidence)
- `/Users/milan.kormout/Projects/personal/graviton/components/body.gd` — `die()` implementation, `death` export var, `queue_free()` usage, `spawn_parent.add_child(node)` pattern
- `/Users/milan.kormout/Projects/personal/graviton/components/explosion.gd` — Full Explosion class: `call_deferred("add_child", area)` for Area2D, `apply_shockwave()`, mask configuration (mask 1 cleared = does not detect Ship layer)
- `/Users/milan.kormout/Projects/personal/graviton/components/enemy-ship.gd` — State enum, `_change_state` idempotency guard, `dying` flag, detection area connection pattern
- `/Users/milan.kormout/Projects/personal/graviton/components/beeliner.gd` — Reference `die()` override, `_on_detection_area_body_entered`, per-instance randomization pattern
- `/Users/milan.kormout/Projects/personal/graviton/components/swarmer.gd` — Reference `_tick_state` with `lerp_angle` rotation, `apply_central_force` usage, additional Area2D pattern (CohesionArea)
- `/Users/milan.kormout/Projects/personal/graviton/prefabs/enemies/swarmer/swarmer.tscn` — Reference for how a non-base Area2D (CohesionArea) is added to an inherited scene
- `/Users/milan.kormout/Projects/personal/graviton/prefabs/ship-bfg-23/ship-bfg-23-explosion.tscn` — Reference explosion: radius=3000, power=50000, energy=500, kinetic=500
- `/Users/milan.kormout/Projects/personal/graviton/prefabs/asteroid-explosion.tscn` — Reference explosion: radius=1000, power=1000, kinetic=50 (baseline for comparison)

### Secondary (MEDIUM confidence)
- Godot Forum: "What is the difference between queue_free() and call_deferred('queue_free')" — confirmed `queue_free()` is safe from physics callbacks in Godot 4; both are processed in the same flush operation
- Godot Forum: Physics callback safety — "Removing a CollisionObject" error is caused by `free()` not `queue_free()`

### Tertiary (LOW confidence)
- WebSearch results on Area2D body_entered signal timing — general community knowledge; no single authoritative source; consistent with observed codebase behavior

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components verified by direct codebase reading
- Architecture: HIGH — patterns extracted from 4 prior enemy implementations in the same codebase
- Pitfalls: MEDIUM/HIGH — most verified by codebase analysis; A1 (explosion mask) is ASSUMED and needs runtime verification
- Explosion values: LOW — numbers derived from comparative analysis of existing scenes; require playtest calibration

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (stable Godot project; no external dependencies that change)
