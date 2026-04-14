# Phase 6: Sniper - Research

**Researched:** 2026-04-12
**Domain:** GDScript enemy AI — standoff-range state machine with flee behavior and telegraphed fire
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Three distance thresholds — all `@export` vars:
- Outside `fight_range` (~900px): SEEKING — approach player
- Inside `comfort_range` (~600px): reverse thrust while still in SEEKING/FIGHTING (within-state behavior, not a state change)
- Inside `flee_range` (~300px): trigger FLEEING state

**D-02:** SEEKING = movement only. No shots fired in SEEKING.

**D-03:** FIGHTING = fire + gentle movement. Reduced corrective thrust, not zero.

**D-04:** States used: IDLING → SEEKING → FIGHTING → FLEEING → SEEKING (cycle).

**D-05:** SEEKING → FIGHTING: player within `fight_range` AND outside `comfort_range`.

**D-06:** FIGHTING → FLEEING: player inside `flee_range`. Stop firing, start retreating.

**D-07:** Comfort band behavior is within-state (reverse thrust), not a state transition.

**D-08:** FLEEING → SEEKING: player moves outside `safe_range` (~700px).

**D-09:** Aim-up pause before each shot: ~1s track-and-rotate, then release.

**D-10:** `@export var aim_up_time: float` (default ~1.0s). Reduced-thrust movement continues during aim-up.

**D-11:** One shot per fire cycle. Single slow projectile.

**D-12:** New `sniper-bullet.tscn` at `prefabs/enemies/sniper/sniper-bullet.tscn`. Structural copy of `beeliner-bullet.tscn`.

**D-13:** Visually distinct — slower travel speed, higher `Damage.energy`. Sprite2D blank (user provides art later).

**D-14:** Bullet spawning: `spawn_parent.add_child(bullet)` at `$Barrel.global_position`.

**D-15:** `sniper.tscn` inherits `base-enemy-ship.tscn`. Only overrides: `@export` values and Fire Timer config. No structural changes.

**D-16:** No picker Area2D in scene (base already omits it — ENM-15).

### Claude's Discretion

- Exact values for `fight_range`, `comfort_range`, `flee_range`, `safe_range` (export vars, tune in playtesting)
- Exact fire rate (fire timer interval) — slow/deliberate relative to Beeliner's 1.5s
- Exact bullet speed and `Damage.energy` — slower and heavier than Beeliner, exact values for playtesting
- Reduced-thrust multiplier while in FIGHTING (e.g. 0.3x of normal thrust)
- Loot drop table — follow Beeliner pattern (coins + ammo, via ItemDropper)
- Sniper bullet sprite — blank for now

### Deferred Ideas (OUT OF SCOPE)

- Sniper sprite — user will provide later; debug `_draw` placeholder inherited from EnemyShip
- Predictive targeting (leading the shot) — deferred to v2.1+
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENM-08 | Sniper maintains standoff distance in SEEKING, fires slow heavy shots in FIGHTING, transitions to FLEEING when player enters close range | All findings below directly enable implementation: state machine structure (Pattern 1), aim-up Timer (Pattern 2), reverse-thrust pattern (Pattern 3), bullet scene (Pattern 4), WaveManager wiring (Pattern 5) |
</phase_requirements>

---

## Summary

Phase 6 adds the Sniper — the second concrete EnemyShip type. The infrastructure from Phases 4 and 5 is fully in place: `EnemyShip` base class, `_change_state` / `steer_toward` helpers, `EnemyBullet` collision override, `WaveManager` spawn pipeline, and the `Beeliner` as a complete pattern to copy. The Sniper is purely additive — no base class changes, no WaveManager changes, no world structural changes.

The Sniper introduces one new behavioral concept relative to the Beeliner: **standoff distance management** using three distance bands and **reverse thrust**. The aim-up telegraph adds a second new concept: a one-shot `Timer` node inserted between the fire timer trigger and the actual `_fire()` call. Both concepts are straightforward with existing GDScript timer and force APIs — no external libraries, no engine workarounds.

**Primary recommendation:** Model `sniper.gd` directly on `beeliner.gd`. Add `_aim_timer: Timer` node alongside `_fire_timer`, drive reverse thrust via `steer_toward(global_position - direction * large_offset)` in FIGHTING and FLEEING, and implement distance-band logic inside `_tick_state`. One new scene (`sniper.tscn`) inheriting `base-enemy-ship.tscn`, one new bullet scene copied from `beeliner-bullet.tscn`.

---

## Standard Stack

### Core (no new dependencies — everything already in the project)

| Component | Source | Purpose | How Used |
|-----------|--------|---------|----------|
| `EnemyShip` (base) | `components/enemy-ship.gd` | State machine, steering, dying guard | `extends EnemyShip` |
| `EnemyBullet` | `components/enemy-bullet.gd` | Bullet with enemy-friendly-fire guard | Sniper bullet extends this |
| `Damage` resource | `components/damage.gd` | Fixed energy damage per bullet | Configured in sniper-bullet.tscn |
| `ItemDropper` | `components/item-dropper.gd` | Weighted loot drops on death | Same pattern as Beeliner |
| `Timer` (Godot built-in) | Godot 4 | Fire timer + aim-up timer | Two Timer nodes in scene |
| `WaveManager` | `components/wave-manager.gd` | Wave spawn integration | Add Sniper scene to `waves` array |

[VERIFIED: codebase — all files confirmed present and read]

**No new packages or installs required.**

---

## Architecture Patterns

### Sniper Directory Structure

```
components/
└── sniper.gd                          # Sniper script (new)

prefabs/enemies/sniper/
├── sniper.tscn                        # Inherits base-enemy-ship.tscn (new)
└── sniper-bullet.tscn                 # Structural copy of beeliner-bullet.tscn (new)
```

---

### Pattern 1: State Machine — _tick_state with three distance bands

The Sniper's `_tick_state` checks `dist` (distance to `_target`) every physics frame and routes behavior. The key difference from Beeliner: distance is checked at three thresholds, and within SEEKING/FIGHTING the comfort band triggers reverse thrust without a state change (D-07).

```gdscript
# Source: beeliner.gd pattern extended with distance bands (VERIFIED: codebase)
func _tick_state(_delta: float) -> void:
    if not _target:
        return
    var dist := global_position.distance_to(_target.global_position)

    match current_state:
        State.SEEKING:
            look_at(_target.global_position)
            if dist < flee_range:
                _change_state(State.FLEEING)
            elif dist < comfort_range:
                # Reverse thrust — back away — D-07: within-state, no transition
                var away := (global_position - _target.global_position).normalized()
                apply_central_force(away * thrust)
            elif dist < fight_range:
                # Sweet spot — transition to FIGHTING
                _change_state(State.FIGHTING)
            else:
                # Outside fight_range — approach
                steer_toward(_target.global_position)

        State.FIGHTING:
            look_at(_target.global_position)
            if dist < flee_range:
                _change_state(State.FLEEING)
            elif dist < comfort_range:
                # Drift back, reduced thrust — D-03, D-07
                var away := (global_position - _target.global_position).normalized()
                apply_central_force(away * thrust * _fighting_thrust_multiplier)
            # else: in sweet spot, apply gentle corrective thrust
            else:
                steer_toward(_target.global_position)
                # Note: steer_toward uses full thrust; multiply by _fighting_thrust_multiplier
                # by overriding or by applying force directly

        State.FLEEING:
            look_at(_target.global_position)
            if dist > safe_range:
                _change_state(State.SEEKING)
            else:
                var away := (global_position - _target.global_position).normalized()
                apply_central_force(away * thrust)
```

**Implementation note on FIGHTING thrust:** `steer_toward` in `EnemyShip` applies `thrust` directly (no multiplier). For FIGHTING reduced thrust (D-03), apply force manually inside `_tick_state` rather than calling `steer_toward`, so the multiplier applies cleanly. [VERIFIED: enemy-ship.gd line 61-63]

---

### Pattern 2: Aim-Up Telegraph — two-timer fire pattern

The aim-up uses a second `Timer` node (`_aim_timer`, one-shot). When `_fire_timer` fires, start `_aim_timer` instead of calling `_fire()` immediately. During aim-up, the Sniper continues movement. When `_aim_timer` fires, call `_fire()`.

```gdscript
# Source: Derived from Beeliner's fire timer pattern (VERIFIED: beeliner.gd lines 36-42, 68-72)

@onready var _fire_timer: Timer = $FireTimer
@onready var _aim_timer: Timer = $AimTimer   # one_shot = true, autostart = false

func _ready() -> void:
    super()
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
    _aim_timer.timeout.connect(_on_aim_timer_timeout)

func _enter_state(new_state: State) -> void:
    if new_state == State.FIGHTING:
        _fire_timer.start()        # begin fire cycle
    if new_state == State.FLEEING:
        _fire_timer.stop()
        _aim_timer.stop()          # cancel any in-progress aim-up

func _exit_state(old_state: State) -> void:
    if old_state == State.FIGHTING:
        _fire_timer.stop()
        _aim_timer.stop()

func _on_fire_timer_timeout() -> void:
    if dying or current_state != State.FIGHTING:
        return
    # Begin aim-up phase — tracking continues in _tick_state
    _aim_timer.start(aim_up_time)

func _on_aim_timer_timeout() -> void:
    if dying or current_state != State.FIGHTING:
        return
    _fire()
```

**Scene nodes required in sniper.tscn:**
- `FireTimer` — `wait_time` ~3.0s, `one_shot = false`, `autostart = false`
- `AimTimer` — `wait_time` set at runtime via `_aim_timer.start(aim_up_time)` (or default `wait_time` set in scene), `one_shot = true`, `autostart = false`

[ASSUMED] — `Timer.start(time_sec)` overrides `wait_time` for that one call in Godot 4. This is standard GDScript Timer API behavior from training data; not separately verified via docs in this session.

---

### Pattern 3: Reverse Thrust (flee / back-away)

`EnemyShip.steer_toward(target)` applies `apply_central_force(direction * thrust)` where direction is normalized from `global_position` toward `target`. [VERIFIED: enemy-ship.gd line 61-63]

To reverse: compute `away = (global_position - target.global_position).normalized()` and call `apply_central_force(away * thrust)` directly. This is the away-from-player pattern for both the comfort-band backing and FLEEING.

No new API needed — `apply_central_force` is already used everywhere.

---

### Pattern 4: Sniper Bullet Scene

Copy `beeliner-bullet.tscn` structure exactly. Change:
- Root node name: `SniperBullet`
- `attack` resource: higher `energy` value (e.g. 20.0–30.0 vs Beeliner's 5.0)
- `mass`, `life`, bullet speed set at spawn time (in `sniper.gd._fire()`)
- `CollisionShape2D` size: can increase for a heavier visual feel (e.g. wider rectangle)
- UID: must be unique — use a new uid string

Beeliner bullet reference values [VERIFIED: beeliner-bullet.tscn]:
- `collision_layer = 256` (layer 9 in Godot's 1-indexed = bit 8 = decimal 256) — wait, 256 = bit 9. But world.gd says layer 3 is Bullets. Let me clarify:

**Physics layer clarification:** [VERIFIED: beeliner-bullet.tscn + world.gd]
- `collision_layer = 256` in the .tscn = decimal 256 = binary `100000000` = bit 9 in 0-indexed = layer 9 in Godot 1-indexed.

Actually, re-reading: `collision_layer = 256` means `2^8 = 256`, which is Godot physics layer 9 (1-indexed). But `world.gd` comments say layer 3 is Bullets. This appears inconsistent.

**Key finding:** The Beeliner bullet uses `collision_layer = 256` (layer 9) and `collision_mask = 1` (layer 1 = Ship). The Sniper bullet must use the same values — copy exactly from beeliner-bullet.tscn. The layer 3 comment in world.gd may refer to something else or be partially outdated. Do not attempt to rationalise — copy the working Beeliner bullet layer config verbatim. [VERIFIED: beeliner-bullet.tscn, world.gd lines 31-37]

Sniper bullet starting values (Claude's discretion, tune in playtesting):
- `energy = 20.0` (4x Beeliner's 5.0 — meaningful damage-per-hit difference)
- `bullet_speed` in `sniper.gd`: ~1500 px/s (vs Beeliner's 4400 — visibly slower)
- `life = 3.0` (slower bullet needs longer life to reach same range)
- `mass = 80.0` (heavier than Beeliner's 50.0 — consistent with "heavy shot" theme)

---

### Pattern 5: WaveManager Integration

`world.gd` configures `$WaveManager.waves` as an array of dictionaries. Adding Sniper requires:
1. `preload` the sniper scene at top of `world.gd`
2. Add a dictionary entry to the `waves` array

```gdscript
# Source: world.gd lines 49-56 (VERIFIED: codebase)
var sniper_model = preload("res://prefabs/enemies/sniper/sniper.tscn")

# In _ready():
$WaveManager.waves = [
    { "enemy_scene": beeliner_model, "count": 3 },
    { "enemy_scene": sniper_model, "count": 1 },   # add for testing
    # ...
]
```

This is the only required world.gd change. WaveManager handles spawn positioning and `spawn_parent` propagation automatically. [VERIFIED: world.gd, wave-manager.gd]

---

### Pattern 6: Death / Loot Drop

Beeliner uses two `ItemDropper` nodes: `CoinDropper` and `AmmoDropper`. It calls both in `die()`:

```gdscript
# Source: beeliner.gd line 73-78 (VERIFIED: codebase)
func die(delay: float = 0.0) -> void:
    if dying:
        return
    _fire_timer.stop()
    _ammo_dropper.drop()
    super(delay)    # Body.die() calls item_dropper.drop() if set
```

`Body.item_dropper` (the `@export` var on Body) is the primary dropper called by `super(delay)`. Beeliner routes coins through `item_dropper = NodePath("CoinDropper")` and ammo through a separate `_ammo_dropper` reference. [VERIFIED: body.gd line 54, beeliner.tscn line 44]

Sniper should follow this same two-dropper pattern. The Sniper's `die()` override must:
1. Stop `_fire_timer` and `_aim_timer`
2. Call `_ammo_dropper.drop()`
3. Call `super(delay)` (which triggers `item_dropper.drop()` for coins)

---

### Anti-Patterns to Avoid

- **Calling `_change_state` in `_tick_state` every frame at the same condition:** `EnemyShip._change_state` guards against same-state transitions (line 52: `if new_state == current_state: return`), so this is safe but noisy. Still, prefer distance checks that only trigger transitions on threshold crossing. [VERIFIED: enemy-ship.gd line 52]
- **Using `linear_velocity =` assignment for movement:** ENM-03 forbids direct velocity assignment. All movement is `apply_central_force`. Max speed is clamped in `_integrate_forces`. [VERIFIED: enemy-ship.gd line 40]
- **Firing during SEEKING:** D-02 explicitly forbids shots in SEEKING. Guard `_fire()` with `if current_state != State.FIGHTING: return`.
- **Not stopping both timers on FLEEING:** If `_aim_timer` is mid-count when FLEEING starts, it must be stopped or a shot fires immediately upon returning to FIGHTING. Stop both in `_enter_state(FLEEING)`.
- **Spawning bullet at `global_position` (self-collision):** Beeliner offsets bullet spawn by 350px past HitBox radius (300px). Sniper must do the same or the bullet collides with its own HitBox. [VERIFIED: beeliner.gd line 62-63]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Telegraph timer | Custom frame counter or `_process` accumulator | `Timer` node with `one_shot = true` | Already used for FireTimer; same API, no extra complexity |
| Aim-toward-player rotation | Manual angle math per frame | `look_at(_target.global_position)` | Godot built-in; used in Beeliner already |
| Distance check | Custom overlap Area2D for range bands | `global_position.distance_to(_target.global_position)` | Instant, no extra nodes; target already stored as `_target` |
| Weighted loot drops | Custom weighted-random logic | `ItemDropper.drop()` | Already implemented, tested, working |
| Physics clamping | Manual velocity normalization | `_integrate_forces` max-speed clamp (inherited) | EnemyShip base class provides this |

---

## Common Pitfalls

### Pitfall 1: Aim timer fires after state change away from FIGHTING

**What goes wrong:** `_aim_timer` is started in FIGHTING. Player closes in, triggering FLEEING. `_aim_timer` fires anyway (it's a one-shot timer that already started). `_on_aim_timer_timeout` is called, which calls `_fire()` while in FLEEING — bullet fires at wrong time.

**Why it happens:** Godot `Timer.stop()` must be called explicitly; changing state does not auto-stop timers.

**How to avoid:** In `_enter_state(State.FLEEING)` — call `_fire_timer.stop()` AND `_aim_timer.stop()`. Also guard `_on_aim_timer_timeout` with `if current_state != State.FIGHTING: return`.

**Warning signs:** Sniper fires one bullet immediately upon re-entering FIGHTING after fleeing.

---

### Pitfall 2: Reverse thrust fights forward momentum — Sniper never flees effectively

**What goes wrong:** `apply_central_force` in FLEEING is counteracted by existing forward velocity accumulated during SEEKING. Sniper appears to flee slowly or oscillates near `flee_range`.

**Why it happens:** `RigidBody2D` has mass and linear damping. Applying an away force doesn't zero velocity — it decelerates then re-accelerates in the opposite direction. At low `thrust` values the flee feels sluggish.

**How to avoid:** Ensure Sniper `thrust` is large enough that the away force overcomes typical approach velocity. The `max_speed` clamp in `_integrate_forces` already limits the flee velocity to a sane maximum. If sluggishness is observed, increase `thrust` or add a small `linear_damp` to the scene.

**Warning signs:** Sniper moves into `flee_range`, player can track it easily, Sniper circle-strafes instead of clearly retreating.

---

### Pitfall 3: UID collision in .tscn files

**What goes wrong:** Copying beeliner-bullet.tscn and changing only content but not the `uid=` string in `[gd_scene ... uid="..."]` causes Godot to treat two scenes as the same resource — one will shadow the other in the editor.

**Why it happens:** UID is a global identifier inside Godot's resource database.

**How to avoid:** Give `sniper-bullet.tscn` and `sniper.tscn` unique UID strings. In Godot 4.6+, the editor auto-generates UIDs on file save; safe to leave a placeholder in the hand-written file and let the editor assign one on first open. Alternatively, use a clearly distinct string like `uid://sniper_scene_001` and `uid://sniper_bullet_001`. [ASSUMED — UID behavior on manual file creation; editor behavior is standard but not verified against Godot 4.6.2 docs in this session]

---

### Pitfall 4: Three-band logic order matters — inner threshold must be checked first

**What goes wrong:** If `_tick_state` checks `dist < fight_range` before `dist < flee_range`, the `flee_range` check is never reached (because `flee_range < fight_range`, so `dist < flee_range` implies `dist < fight_range`).

**Why it happens:** Nested distance bands must be evaluated innermost-first (smallest radius → largest).

**How to avoid:** Always order checks: `flee_range` first, then `comfort_range`, then `fight_range`. See Pattern 1 above.

**Warning signs:** FLEEING never triggers even when player is at point-blank range.

---

### Pitfall 5: Sniper fires too rapidly — aim-up meaningless

**What goes wrong:** `aim_up_time = 1.0` but `FireTimer.wait_time = 0.5` — the Sniper fires before aim-up completes. Or `aim_up_time` is much shorter than intended.

**Why it happens:** `_aim_timer.start(aim_up_time)` uses the `aim_up_time` export var directly. If export default is wrong, the feeling is lost.

**How to avoid:** Set `FireTimer.wait_time` to something meaningfully longer than `aim_up_time` (e.g. 3.0s fire interval, 1.0s aim-up). Document starting values in the plan.

---

## Code Examples

### Minimum viable Sniper script skeleton

```gdscript
# Source: beeliner.gd pattern with distance-band extensions (VERIFIED: codebase)
class_name Sniper
extends EnemyShip

@export var fight_range: float = 900.0
@export var comfort_range: float = 600.0
@export var flee_range: float = 300.0
@export var safe_range: float = 700.0
@export var aim_up_time: float = 1.0
@export var bullet_speed: float = 1500.0

const FIGHTING_THRUST_MULT := 0.3

var _target: Node2D = null
var _bullet_scene := preload("res://prefabs/enemies/sniper/sniper-bullet.tscn")

@onready var _fire_timer: Timer = $FireTimer
@onready var _aim_timer: Timer = $AimTimer
@onready var _ammo_dropper: ItemDropper = $AmmoDropper

func _ready() -> void:
    super()
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
    _aim_timer.timeout.connect(_on_aim_timer_timeout)

func _on_detection_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip and current_state == State.IDLING:
        _target = body
        _change_state(State.SEEKING)

func _tick_state(_delta: float) -> void:
    if not _target:
        return
    var dist := global_position.distance_to(_target.global_position)
    match current_state:
        State.SEEKING:
            look_at(_target.global_position)
            if dist < flee_range:
                _change_state(State.FLEEING)
            elif dist < comfort_range:
                var away := (global_position - _target.global_position).normalized()
                apply_central_force(away * thrust)
            elif dist < fight_range:
                _change_state(State.FIGHTING)
            else:
                steer_toward(_target.global_position)
        State.FIGHTING:
            look_at(_target.global_position)
            if dist < flee_range:
                _change_state(State.FLEEING)
            elif dist < comfort_range:
                var away := (global_position - _target.global_position).normalized()
                apply_central_force(away * thrust * FIGHTING_THRUST_MULT)
            else:
                var toward := (_target.global_position - global_position).normalized()
                apply_central_force(toward * thrust * FIGHTING_THRUST_MULT)
        State.FLEEING:
            if dist > safe_range:
                _change_state(State.SEEKING)
            else:
                var away := (global_position - _target.global_position).normalized()
                apply_central_force(away * thrust)

func _enter_state(new_state: State) -> void:
    if new_state == State.FIGHTING:
        _fire_timer.start()
    if new_state == State.FLEEING:
        _fire_timer.stop()
        _aim_timer.stop()

func _exit_state(old_state: State) -> void:
    if old_state == State.FIGHTING:
        _fire_timer.stop()
        _aim_timer.stop()

func _on_fire_timer_timeout() -> void:
    if dying or current_state != State.FIGHTING:
        return
    _aim_timer.start(aim_up_time)

func _on_aim_timer_timeout() -> void:
    if dying or current_state != State.FIGHTING:
        return
    _fire()

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
        push_warning("Sniper: spawn_parent not set")

func die(delay: float = 0.0) -> void:
    if dying:
        return
    _fire_timer.stop()
    _aim_timer.stop()
    _ammo_dropper.drop()
    super(delay)
```

---

### Sniper bullet scene (minimal, verbatim from beeliner-bullet.tscn pattern)

Key differences from Beeliner bullet [VERIFIED: beeliner-bullet.tscn]:
- `energy = 20.0` (vs 5.0)
- `mass = 80.0` (vs 50.0)
- `life = 3.0` (vs 2.0 — slower bullet needs longer range)
- `collision_layer = 256`, `collision_mask = 1` — same as Beeliner (copy verbatim)
- New unique UID

---

## State of the Art

| Phase 5 Pattern | Phase 6 Extension | Notes |
|----------------|-------------------|-------|
| Single fire timer → `_fire()` | Two timers: fire timer starts aim timer, aim timer calls `_fire()` | Standard Godot Timer chaining |
| `steer_toward(player)` only | `steer_toward` + reverse force based on distance band | Same `apply_central_force` API |
| Two states: SEEKING → FIGHTING | Four states: IDLING → SEEKING → FIGHTING → FLEEING → SEEKING | All states already in base `State` enum |
| No FLEEING implementation | FLEEING: away force + `safe_range` recovery condition | Pure distance check |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Timer.start(time_sec)` overrides `wait_time` for that call in Godot 4 | Pattern 2 | If false: set `_aim_timer.wait_time = aim_up_time` before `_aim_timer.start()` — trivial fix |
| A2 | Editor auto-generates UID on first save for manually created .tscn files with placeholder UIDs | Pitfall 3 | If false: must generate valid UID manually or via `uid://` convention; low-stakes, discoverable immediately in editor |

**2 assumed claims — both low-stakes and immediately discoverable during implementation.**

---

## Open Questions

1. **`look_at` during aim-up: should the Sniper continue tracking or lock rotation?**
   - What we know: D-09 says "tracks/rotates toward the player for ~1 second" — tracking is desired
   - What's unclear: `look_at` is called in `_tick_state` every frame; aim timer is a separate concern. Tracking naturally continues.
   - Recommendation: No special handling needed — `look_at` in `_tick_state(FIGHTING)` continues running during aim-up with no changes.

2. **FIGHTING → comfort band: should `look_at` still apply when backing away?**
   - What we know: D-03 says "reduced corrective thrust while firing" — the Sniper is still aiming
   - Recommendation: Yes, keep `look_at(_target)` in FIGHTING regardless of which sub-band applies. The Sniper should always face the player while in FIGHTING.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 6 is purely GDScript code and scene files. No external tools, CLIs, runtimes, or services beyond the Godot editor are required.

---

## Validation Architecture

`nyquist_validation: false` in `.planning/config.json` — this section is omitted per config.

---

## Security Domain

Not applicable — this is a local single-player game with no network, authentication, user input storage, or external data sources.

---

## Sources

### Primary (HIGH confidence)

- `components/enemy-ship.gd` — EnemyShip base class: State enum, `_change_state`, `steer_toward`, `_integrate_forces`, dying guard [VERIFIED: read in full]
- `components/beeliner.gd` — Beeliner implementation: fire timer pattern, bullet spawn, state hooks, loot drop [VERIFIED: read in full]
- `prefabs/enemies/beeliner/beeliner.tscn` — Beeliner scene: node structure, collision layers, ItemDropper config, FireTimer config [VERIFIED: read in full]
- `prefabs/enemies/beeliner/beeliner-bullet.tscn` — Bullet scene: layer bits, Damage resource, shape [VERIFIED: read in full]
- `components/enemy-bullet.gd` — EnemyBullet: friendly-fire guard, debug `_draw` [VERIFIED: read in full]
- `components/body.gd` — Body base: `spawn_parent`, `dying`, `die()`, `item_dropper.drop()` call [VERIFIED: read in full]
- `components/damage.gd` — Damage resource: `energy`, `kinetic`, `calculate()` [VERIFIED: read in full]
- `components/item-dropper.gd` — ItemDropper: `drop()`, weighted roll [VERIFIED: read in full]
- `components/wave-manager.gd` — WaveManager: `trigger_wave`, `_spawn_enemy`, spawn positioning [VERIFIED: read in full]
- `world.gd` — Physics layer table (lines 30-37), WaveManager setup (lines 49-56), preload pattern [VERIFIED: read in full]
- `prefabs/enemies/base-enemy-ship.tscn` — Base scene structure: nodes, default shapes [VERIFIED: read in full]

### Secondary (MEDIUM confidence)

None required — all information drawn from codebase.

### Tertiary (LOW confidence — ASSUMED)

- A1: `Timer.start(time_sec)` overrides `wait_time` — standard Godot 4 API, training knowledge
- A2: Editor UID auto-generation on first save — standard Godot 4 behavior, training knowledge

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components verified in codebase
- Architecture patterns: HIGH — derived directly from working Beeliner implementation
- Pitfalls: HIGH — derived from reading actual code paths and timer/state interactions
- Assumed claims: 2, both low-stakes

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable GDScript codebase; changes would come from repo modifications, not upstream)
