# Phase 7: Flanker - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the Flanker — the third concrete enemy type. The Flanker orbits the player in LURKING state using tangential steering force + radius correction, then breaks into a rapid-fire attack run in FIGHTING, then returns to orbit. One new bullet scene. No WaveManager changes; Flanker is wired into the existing wave composition array.

Requirements covered: ENM-09.

</domain>

<decisions>
## Implementation Decisions

### Attack burst (FIGHTING state)
- **D-01:** Rapid salvo — multiple bullets fired in quick succession (~4–6 bullets at ~0.2–0.3s intervals) aimed straight ahead from the barrel. Not a shotgun spread; each bullet travels the same direction.
- **D-02:** Fire is driven by `_fire_timer` running continuously while in FIGHTING. Each timeout fires one bullet. The rapid-fire feel comes from the short timer interval, not from firing multiple bullets per call (unlike Beeliner's per-call spread).
- **D-03:** New `flanker-bullet.tscn` — a structural copy of `sniper-bullet.tscn`. Located at `prefabs/enemies/flanker/flanker-bullet.tscn`. No sprite yet; leave Sprite2D blank. Fixed `Damage.energy` resource (ENM-06).
- **D-04:** Bullet spawning follows established pattern: `spawn_parent.add_child(bullet)` at `$Barrel.global_position` (ENM-05).

### FIGHTING exit — return to orbit
- **D-05:** Range-based exit. The Flanker stays in FIGHTING while the player is within `return_range`. When the player's distance exceeds `return_range`, transition back to LURKING and resume orbit.
- **D-06:** `return_range > fight_range` to create hysteresis and prevent rapid oscillation between states at the boundary.
- **D-07:** No FLEEING state. The Flanker is aggressive — it only disengages when the player creates distance, not on its own initiative.
- **D-08:** Fire timer stops on `_exit_state(FIGHTING)` and starts on `_enter_state(FIGHTING)` — same pattern as Beeliner and Sniper.

### LURKING → FIGHTING trigger
- **D-09:** Distance-based: transition LURKING → FIGHTING when the Flanker's position is within `fight_range` of the player during orbit. Since orbit radius varies per instance, Flankers with smaller orbits will attack more frequently.
- **D-10:** This creates a natural attack cycle: orbit → drift close → attack → player escapes → orbit again. No separate attack timer needed.

### State machine
- **D-11:** States used: IDLING → SEEKING → LURKING → FIGHTING → LURKING (cycle).
- **D-12:** IDLING → SEEKING: detection area `body_entered` triggers when player enters detection radius (same as Beeliner/Sniper).
- **D-13:** SEEKING → LURKING: when the Flanker closes to within `orbit_entry_range` of the player, transition to LURKING and begin orbital motion.
- **D-14:** LURKING → FIGHTING: when distance to player < `fight_range` during orbit.
- **D-15:** FIGHTING → LURKING: when distance to player > `return_range`.
- **D-16:** No FLEEING state for the Flanker.

### Orbit mechanics (LURKING state)
- **D-17:** Orbit uses tangential steering force + radius correction, as specified in ENM-09. The tangential component keeps the Flanker circling; the radial component corrects drift toward or away from the desired `orbit_radius`.
- **D-18:** Orbit direction (clockwise vs counter-clockwise) is randomized at `_ready()` — `orbit_direction` set to `1.0` or `-1.0` with 50/50 probability. This satisfies the success criterion that orbit direction varies between instances.
- **D-19:** Orbit radius is an `@export var orbit_radius: float` whose default is multiplied by `randf_range(0.8, 1.3)` in `_ready()`, giving each Flanker a slightly different orbit size. Combined with `orbit_direction`, no two Flankers behave identically.
- **D-20:** While in LURKING, the Flanker does not fire. The orbit is purely repositioning/setup behavior.

### Scene inheritance and loot
- **D-21:** `flanker.tscn` inherits `base-enemy-ship.tscn`. Only overrides: `@export` defaults, FireTimer configuration. No structural changes.
- **D-22:** No picker `Area2D` in the Flanker scene (inherited base already omits it — ENM-15).
- **D-23:** Loot drop table (configured in ItemDropper): coins + ammo following the Beeliner/Sniper pattern. Exact weights at Claude's discretion.
- **D-24:** `die()` override: stop fire timer, call `_ammo_dropper.drop()`, then `super(delay)` — identical pattern to Beeliner and Sniper.

### Claude's Discretion
- Exact values for `orbit_radius` default, `orbit_entry_range`, `fight_range`, `return_range` (export vars, tune in playtesting)
- Exact fire timer interval for the rapid salvo (suggested ~0.2–0.3s)
- Exact bullet speed and `Damage.energy` for the Flanker bullet
- Tangential steering force formula: cross product of the toward-player unit vector with `Vector2(0, 1)`, scaled by thrust and `orbit_direction`
- Radius correction magnitude (additional radial force to keep Flanker on orbit radius)
- Loot drop weights/counts (follow Beeliner/Sniper precedent)

</decisions>

<specifics>
## Specific Ideas

- Distinct attack feel from Beeliner: Beeliner fires one simultaneous 3-bullet spread; Flanker fires single bullets in rapid succession — reads as a "strafing run" rather than a shotgun.
- The orbit-then-attack cycle creates an emergent rhythm: player watches the Flanker circling, knows an attack is imminent as it closes in. Raises tension without being a straight charge.
- No sprite needed for Phase 7 — debug `_draw` placeholder (inherited from EnemyShip base class) is sufficient.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — ENM-09: full acceptance criteria for Phase 7 (Flanker orbit + LURKING state)
- `.planning/ROADMAP.md` §Phase 7 — Goal, success criteria, and phase boundary

### Base class (read before extending)
- `components/enemy-ship.gd` — Full EnemyShip base class: State enum, `_change_state`, `steer_toward`, `_integrate_forces` max_speed clamp, dying guard, detection wiring
- `prefabs/enemies/base-enemy-ship.tscn` — Scene to inherit from: root node + CollisionShape2D + Sprite2D + DetectionArea + HitBox + Barrel + ItemDropper structure

### Concrete type references (read both — Flanker borrows from each)
- `components/beeliner.gd` — Fire timer pattern (`_enter_state`/`_exit_state` start/stop), `_fire()` spawning, `die()` override, per-instance randomization in `_ready()`
- `components/sniper.gd` — Detection `body_exited` handling (target validation), range-based state transitions in `_tick_state`
- `prefabs/enemies/beeliner/beeliner-bullet.tscn` — Bullet scene structure to copy for `flanker-bullet.tscn`
- `prefabs/enemies/sniper/sniper-bullet.tscn` — Alternative reference for bullet scene

### Physics layers
- `world.gd` lines 28–36 — Physics layer table (Ship=1, Weapons=2, Bullets=3, Asteroids=4, Explosions=5, Coins=6, Ammo=7, WeaponItem=8) — Flanker bullet must be on layer 3, masked to hit Ship (1)

### Drop table pattern
- `components/item-dropper.gd` — `drop()`, `roll()`, `ItemDrop` model: how to configure loot table

### World integration
- `world.gd` — WaveManager wave composition array where Flanker scene gets added for testing; no new keyboard shortcuts needed

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `EnemyShip.steer_toward(target_position)` — applies `apply_central_force` toward a target; Flanker uses a modified version for tangential orbit (perpendicular to toward-player vector) plus a radial correction component
- `EnemyShip._change_state()` — handles exit/enter/print; Flanker calls this directly
- `Body.spawn_parent` — already propagates; Flanker bullet spawning uses this
- `Beeliner._fire()` + fire timer pattern — exact model for Flanker's FIGHTING state (minus the spread angles)
- `Sniper._on_detection_area_body_exited()` — pattern for resetting `_target` when player leaves detection area mid-SEEKING

### Established Patterns
- `spawn_parent.add_child(bullet)` at `$Barrel.global_position` — MANDATORY per ENM-05
- `@export` for all tunable values — `orbit_radius`, `orbit_entry_range`, `fight_range`, `return_range`, `bullet_speed` all as exports
- `thrust *= randf_range(0.8, 1.2)` and `max_speed *= randf_range(0.8, 1.2)` in `_ready()` for per-instance variation
- `orbit_direction` set to `1.0` or `-1.0` in `_ready()` for CW/CCW randomization
- Scene inheritance: `flanker.tscn` inherits `base-enemy-ship.tscn` — only override Sprite2D (blank for now) and export defaults

### Integration Points
- `world.gd` WaveManager `waves` array: add `{ "enemy_scene": flanker.tscn, "count": N }` entry for testing
- No other `world.gd` changes needed (wave trigger key already exists from Phase 5)
- Flanker fire timer node: must be added to `flanker.tscn` in the editor (not in base scene) — same as Beeliner/Sniper pattern

</code_context>

<deferred>
## Deferred Ideas

- Flanker sprite — user will provide asset later; Phase 7 uses debug `_draw` placeholder
- Escape/evade behavior if player gets within very tight range — not needed; Flanker just resumes orbit (D-07)
- Group coordination between multiple Flankers — deferred to v2.1+

</deferred>

---

*Phase: 07-flanker*
*Context gathered: 2026-04-12*
