# Phase 8: Swarmer - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the Swarmer — the fourth concrete enemy type. Swarmers spawn in a wave cluster, seek the player from different angles using individual steering offsets, fire weak bullets while FIGHTING, and maintain loose group coherence via thrust reduction + separation push when near groupmates. One new bullet scene. No WaveManager changes; Swarmer is wired into the existing wave composition array.

Requirements covered: ENM-10.

</domain>

<decisions>
## Implementation Decisions

### Fire behavior (ENM-10)
- **D-01:** Swarmer fires weak bullets while in FIGHTING state — same Timer-based fire pattern as Beeliner/Flanker. Low `Damage.energy` value (tuned to be lighter than Beeliner). The threat is numbers, not firepower.
- **D-02:** New `swarmer-bullet.tscn` — a structural copy of `beeliner-bullet.tscn`. Located at `prefabs/enemies/swarmer/swarmer-bullet.tscn`. Leave Sprite2D blank; user will provide art later.
- **D-03:** Bullet spawning follows established pattern: `spawn_parent.add_child(bullet)` at `$Barrel.global_position` (ENM-05). Fixed `Damage.energy` resource (ENM-06).

### Angle divergence — multi-angle approach
- **D-04:** Each Swarmer picks a random angular offset (`_angle_offset: float`) in `_ready()`, sampled from `randf_range(-40.0, 40.0)` degrees. This offset is applied to the steering direction during SEEKING: instead of steering directly toward `_target.global_position`, the Swarmer steers toward a point that is `_angle_offset` degrees off the direct line to the player.
- **D-05:** The angular offset is constant per-instance (baked in `_ready()`), so each Swarmer in a cluster converges on the player from a consistently different bearing rather than oscillating.

### Proximity cohesion — thrust reduction + separation push
- **D-06:** Swarmers detect nearby groupmates using an `Area2D` ("CohesionArea") with a configurable `@export var cohesion_radius: float`. The CohesionArea's collision layer/mask is set to detect only the Ship layer (same layer Swarmers themselves are on) — so Swarmers sense each other without triggering the hitbox or detection area logic.
- **D-07:** When one or more Swarmers are within `cohesion_radius`, the Swarmer applies two forces each physics frame:
  1. **Thrust multiplier**: multiply the applied steering force by `@export var cohesion_thrust_scale: float` (default ~0.3) — the Swarmer slows dramatically.
  2. **Separation push**: for each nearby Swarmer, apply a force in the away-from-groupmate direction, scaled by `@export var separation_force: float`. Net effect: Swarmers don't pass through each other and maintain loose spacing.
- **D-08:** Cohesion applies in all states (SEEKING and FIGHTING) so the swarm stays coherent even during combat — it's a physics property, not a state-machine behavior.

### Cluster spawn
- **D-09:** No WaveManager changes needed. "Cluster-spawned" means multiple Swarmers arrive in the same wave (same `waves` array entry). ENM-14 minimum-separation spawning already spaces them close enough relative to their proximity cohesion radius. The cluster feel comes from the count (e.g., 4–6 Swarmers per wave) rather than a special spawn mode.

### State machine
- **D-10:** States used: IDLING → SEEKING → FIGHTING → (SEEKING or IDLING). Same detection-triggered entry as all other enemies.
- **D-11:** SEEKING → FIGHTING: player within `fight_range`. Start fire timer.
- **D-12:** FIGHTING → SEEKING: player moves outside `fight_range` (with a small hysteresis buffer to prevent rapid oscillation).
- **D-13:** No FLEEING, no LURKING, no EVADING. The Swarmer is purely aggressive.

### Scene inheritance and loot
- **D-14:** `swarmer.tscn` inherits `base-enemy-ship.tscn`. Structural additions: one `Timer` node (FireTimer) and one `Area2D` node (CohesionArea with `CollisionShape2D`). Only overrides: `@export` defaults. No picker `Area2D` (ENM-15).
- **D-15:** Swarmer has **low HP** (lower than Beeliner). Exact value at Claude's discretion.
- **D-16:** Loot drop table (configured in ItemDropper): coins + ammo following established pattern. Exact weights at Claude's discretion.
- **D-17:** `die()` override: stop fire timer, call `_ammo_dropper.drop()`, then `super(delay)` — identical pattern to prior enemy types.

### Claude's Discretion
- Exact `fight_range` value (export var, tune in playtesting)
- Exact `cohesion_radius` (should be slightly larger than the Swarmer's collision shape radius * 2)
- Exact `cohesion_thrust_scale` (suggested: ~0.3)
- Exact `separation_force` magnitude
- Fire timer interval — should feel faster/lighter than Beeliner (more of a harass rate)
- Exact bullet speed and `Damage.energy` — noticeably lower than Beeliner
- Swarmer base HP value (low — should die in fewer hits than Beeliner)
- Per-instance thrust/max_speed variation: `thrust *= randf_range(0.8, 1.2)`, `max_speed *= randf_range(0.8, 1.2)` in `_ready()` (established pattern)

</decisions>

<specifics>
## Specific Ideas

- The Swarmer's danger is numerical: individually weak (low HP, weak bullets), but 4–6 attacking from different angles creates chaotic pressure. Researcher should keep this in mind when suggesting tuning baselines.
- Angular offset in `_ready()` is the key mechanism for multi-angle approach — simple, deterministic per instance, no runtime cost.
- Cohesion is a physics property (always-on), not a state — Swarmers self-organize whether in SEEKING or FIGHTING.
- The CohesionArea uses the Ship layer (layer 1) so Swarmers detect each other; the detection mask must be configured to NOT detect the player ship to avoid interference with the DetectionArea behavior.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — ENM-10: full acceptance criteria for Phase 8 (Swarmer)
- `.planning/ROADMAP.md` §Phase 8 — Goal, success criteria, and phase boundary

### Base class (read before extending)
- `components/enemy-ship.gd` — Full EnemyShip base class: State enum, `_change_state`, `steer_toward`, `_integrate_forces` max_speed clamp, dying guard, detection wiring
- `prefabs/enemies/base-enemy-ship.tscn` — Scene to inherit from: root node + CollisionShape2D + Sprite2D + DetectionArea + HitBox + Barrel + ItemDropper structure

### Concrete type references (read both — Swarmer borrows fire pattern from Beeliner, range transitions from Flanker)
- `components/beeliner.gd` — Fire timer pattern, `_fire()` spawning, `die()` override, per-instance randomization in `_ready()`
- `components/flanker.gd` — Range-based SEEKING/FIGHTING transitions with hysteresis, `body_exited` target reset
- `prefabs/enemies/beeliner/beeliner-bullet.tscn` — Scene structure to copy for `swarmer-bullet.tscn`
- `components/enemy-bullet.gd` — Bullet class used by all enemy bullets

### Physics layers
- `world.gd` lines 28–36 — Physics layer table (Ship=1, Weapons=2, Bullets=3, Asteroids=4, Explosions=5, Coins=6, Ammo=7, WeaponItem=8)
  - Swarmer bullet: layer 3 (Bullets), mask to hit Ship (1)
  - CohesionArea: layer 0 (no own layer), mask on Ship (1) — detects Swarmers but not player (both are Ship layer; use group check in signal handler to filter)

### Drop table pattern
- `components/item-dropper.gd` — `drop()`, `roll()`, `ItemDrop` model

### World integration
- `world.gd` — WaveManager `waves` array where Swarmer scene gets added for testing; no new keyboard shortcuts needed

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `EnemyShip.steer_toward(target_position)` — applies `apply_central_force` toward a target; Swarmer uses a rotated variant during SEEKING (apply offset angle to direction vector before calling or inline the force calculation)
- `EnemyShip._change_state()` — handles exit/enter/print; Swarmer calls this directly
- `Body.spawn_parent` — already propagates; Swarmer bullet spawning uses this
- `Beeliner._fire()` + fire timer pattern — exact model for Swarmer's FIGHTING state
- `Flanker._on_detection_area_body_exited()` — pattern for resetting `_target` when player leaves detection area

### Established Patterns
- `spawn_parent.add_child(bullet)` at `$Barrel.global_position` — MANDATORY per ENM-05
- `@export` for all tunable values — `fight_range`, `cohesion_radius`, `cohesion_thrust_scale`, `separation_force`, `bullet_speed` all as exports
- `thrust *= randf_range(0.8, 1.2)` and `max_speed *= randf_range(0.8, 1.2)` in `_ready()` for per-instance variation
- `_angle_offset: float = deg_to_rad(randf_range(-40.0, 40.0))` in `_ready()` — new Swarmer-specific pattern

### CohesionArea implementation hint
The CohesionArea `body_entered`/`body_exited` signals can maintain a `_nearby_swarmers: Array[EnemyShip]` list. In `_tick_state`, check if `_nearby_swarmers.size() > 0` to apply cohesion forces. Filter by `body is Swarmer` in the signal handler (not `body is PlayerShip`) to avoid player detection interference.

### Integration Points
- `world.gd` WaveManager `waves` array: add `{ "enemy_scene": swarmer.tscn, "count": 5 }` (or similar count) for testing
- No other `world.gd` changes needed

</code_context>

<deferred>
## Deferred Ideas

- Swarmer sprite — user will provide asset later; Phase 8 uses debug `_draw` placeholder
- Full Boids alignment + cohesion (velocity matching, center-of-mass attraction) — explicitly out of scope per REQUIREMENTS.md; current thrust reduction + separation is the approved simplified version
- Group attack coordination (e.g., Swarmers signal each other when to FIGHT) — deferred to v2.1+

</deferred>

---

*Phase: 08-swarmer*
*Context gathered: 2026-04-13*
