# Phase 9: Suicider - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the Suicider — the fifth and final concrete enemy type. Charges the player using a locked torpedo vector (not continuous tracking), accelerates as it closes in, and detonates via the existing `Explosion` component on contact with the player OR when shot to death. No fire logic. No loot drops. One new explosion scene. No WaveManager changes — Suicider wires into the existing wave composition array.

Requirements covered: ENM-11.

</domain>

<decisions>
## Implementation Decisions

### Charge behavior — locked vector + acceleration ramp
- **D-01:** On SEEKING entry (when DetectionArea first detects the player), the Suicider locks in its target position at that moment. It steers toward that **fixed world position** for the duration of the run — not the player's current position. This is the "lead-in lock" / torpedo mechanic: the player can dodge by moving sideways during the approach window.
- **D-02:** Thrust ramps up as the Suicider closes range. Multiply applied steering force by a factor that increases as distance to the locked target decreases (e.g., `thrust_multiplier = 1.0 + (1.0 - dist / detection_radius)` clamped to [1.0, 2.0]). Starts sluggish, becomes very dangerous at close range.
- **D-03:** Re-acquires on long miss — if the Suicider reaches or passes its locked target position without achieving contact, it re-enters SEEKING and locks in a new vector. Can circle back for a second attempt. This prevents it from flying uselessly offscreen after a dodge.

### Contact detonation — ContactArea2D approach
- **D-04:** Add a dedicated `ContactArea2D` (Area2D) to the suicider scene with a small collision radius (~30–35px, matching the ship collision shape). Set `collision_layer = 0`, `collision_mask = 1` (Ship layer). Connect `body_entered` in `suicider.gd`. When a `PlayerShip` body enters → call `die()`.
- **D-05:** Do NOT repurpose the HitBox for contact detection. HitBox has `collision_mask = 4` (Bullets only) and serves a different purpose (taking bullet damage). These are separate concerns.
- **D-06:** Double-trigger guard: the existing `if dying: return` in the signal handler is sufficient. `die()` sets `dying = true` synchronously before queue_free, so any subsequent `body_entered` signals (e.g., from contact signal spam) hit the guard and return early.

### Explosion delivery — Body.death mechanism
- **D-07:** Use the established `Body.death` export var mechanism. Assign `suicider-explosion.tscn` as the `death` export on the Suicider scene. When `die()` is called (for any reason — contact or shot to death), `Body.die()` automatically spawns the explosion at `global_position`. No manual explosion instantiation needed in `die()` override.
- **D-08:** Create `prefabs/enemies/suicider/suicider-explosion.tscn` — a new scene using `Explosion` component. Large + devastating: radius ~400–500px, high `Damage.energy`, high `power` value (strong knockback that visibly launches the player).

### Threat profile
- **D-09:** Speed: **faster than Beeliner** (higher `max_speed` export default). With the acceleration ramp (D-02), the Suicider is extremely fast at close range. Exact value at Claude's discretion — should feel noticeably quicker than Beeliner.
- **D-10:** HP: **fragile — less than Beeliner**. Must be killed as a priority target. If the player ignores it, the explosion is severe. High-risk, high-pressure enemy.

### Scene structure — stripped down
- **D-11:** Remove the Barrel node. No fire logic, no barrel needed. The suicider scene is the simplest of all enemy types.
- **D-12:** No loot drops. No ItemDropper node needed. No coins, no ammo. Pure threat — no reward for killing it. The `die()` override calls no drop logic.

### State machine
- **D-13:** States used: IDLING → SEEKING → (contact or death detonation). No FIGHTING state, no FLEEING, no LURKING. The Suicider enters SEEKING on detection and stays there until it detonates or dies.
- **D-14:** `die()` override: set any needed cleanup (stop any timers if added), then `super(delay)`. No ammo dropper. The `death` scene handles the explosion spawn via base `Body.die()`.

### Claude's Discretion
- Exact `max_speed` (should be noticeably faster than Beeliner's default)
- Exact `thrust` value and acceleration ramp formula / clamp range
- Exact locked-vector re-acquisition trigger: detect when Suicider has passed the locked target (use dot product or distance-shrinking-then-growing logic)
- Exact `suicider-explosion.tscn` values: `radius` (~400–500), `power`, `attack.energy`, `attack.kinetic`, animation/particles choices
- HP value (just "less than Beeliner" — exact number at discretion)
- Per-instance speed variation: `thrust *= randf_range(0.8, 1.2)`, `max_speed *= randf_range(0.8, 1.2)` (established pattern)
- ContactArea2D exact radius (match or slightly exceed collision shape radius)

</decisions>

<specifics>
## Specific Ideas

- The Suicider's threat comes from the combination: locked vector (dodge window exists early) + acceleration ramp (closing in becomes very scary) + devastating explosion (failure to dodge is severely punishing).
- Dodge mechanic: player sees the Suicider lock in, has a brief window to move perpendicular to its vector. If they don't, it hits. If they do but slowly, the re-acquire (D-03) gives it a second run.
- "Fast + fragile" means the player is rewarded for vigilance and punished for ignoring it — not for tanking it.
- No loot = intentional. The Suicider is a pure threat, not a reward opportunity.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — ENM-11: full acceptance criteria for Phase 9 (Suicider)
- `.planning/ROADMAP.md` §Phase 9 — Goal, success criteria, and phase boundary

### Base class (read before extending)
- `components/enemy-ship.gd` — Full EnemyShip base class: State enum, `_change_state`, `steer_toward`, `_integrate_forces` max_speed clamp, dying guard, detection wiring, HitBox setup
- `prefabs/enemies/base-enemy-ship.tscn` — Scene to inherit from: root node structure, HitBox mask=4 (Bullets), DetectionArea mask=1 (Ship)

### Explosion component (core to this phase)
- `components/explosion.gd` — Full Explosion class: `radius`, `power`, `attack` (Damage resource), `area`, `apply_shockwave()`, `apply_damage()`, `apply_kickback()`, `spawn_parent` propagation
- `prefabs/ship-bfg-23/ship-bfg-23-explosion.tscn` — Reference explosion scene (ship-scale): use as size/power template for suicider explosion

### Closest analog (no fire, die() override pattern)
- `components/beeliner.gd` — Closest analog for `die()` override pattern, `_on_detection_area_body_entered` target lock, per-instance randomization in `_ready()`
- `prefabs/enemies/beeliner/beeliner.tscn` — Reference for inherited scene structure (suicider will be simpler — no Barrel, no FireTimer, no AmmoDropper)

### Physics layers
- `world.gd` lines 28–36 — Physics layer table (Ship=1, Weapons=2, Bullets=3, Asteroids=4, Explosions=5, Coins=6, Ammo=7, WeaponItem=8)
  - ContactArea2D: `collision_layer = 0`, `collision_mask = 1` (Ship layer — detects PlayerShip)
  - HitBox: existing mask=4 (Bullets) — unchanged, handles bullet damage

### World integration
- `world.gd` — WaveManager `waves` array where Suicider scene gets added for testing

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `components/explosion.gd` — Drop-in explosion node. Configure via export vars on the scene. Handles its own Area2D, damage, shockwave, particles, audio, and self-cleanup.
- `components/body.gd` `die()` — Already spawns `death` PackedScene at global_position with spawn_parent propagation. Zero extra code needed for explosion delivery.

### Established Patterns
- `Body.death` export var: assign a PackedScene; die() handles instantiation + positioning. Used by asteroids and the player ship — natural fit for Suicider.
- `dying` flag guard: set synchronously in die() before queue_free. All signal handlers check `if dying: return`. Double-trigger proof for contact spam.
- Per-instance randomization in `_ready()`: `thrust *= randf_range(0.8, 1.2)`, `max_speed *= randf_range(0.8, 1.2)` — established across Beeliner, Flanker, Swarmer.

### Integration Points
- `base-enemy-ship.tscn` — Suicider scene inherits this. Structural changes: remove Barrel; add ContactArea2D; assign death scene.
- `world.gd` WaveManager `waves` array — add Suicider scene for playtest wave. No WaveManager code changes.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Suicider is the last enemy in v2.0.

</deferred>

---

*Phase: 09-suicider*
*Context gathered: 2026-04-13*
