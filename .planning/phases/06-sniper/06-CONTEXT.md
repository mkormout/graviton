# Phase 6: Sniper - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the Sniper — the second concrete enemy type. The Sniper holds a preferred standoff distance, telegraphs shots before firing, and flees when the player closes in. One new bullet scene. No WaveManager changes; Sniper is wired into the existing wave composition array.

Requirements covered: ENM-08.

</domain>

<decisions>
## Implementation Decisions

### Standoff mechanics (core behavior)
- **D-01:** Two-range band movement. The Sniper operates across three distance thresholds (all `@export` vars):
  - Outside `fight_range` (e.g. ~900px): approach player (SEEKING)
  - Inside `comfort_range` (e.g. ~600px, must be < `fight_range`): reverse thrust — back away from player — still in SEEKING/FIGHTING, not yet FLEEING
  - Inside `flee_range` (e.g. ~300px, must be < `comfort_range`): trigger FLEEING state
- **D-02:** SEEKING = movement only. No shots fired in SEEKING. The Sniper repositions until it can enter FIGHTING at the right range.
- **D-03:** FIGHTING = fire + gentle movement. Sniper applies reduced corrective thrust while firing (not zero) to maintain standoff. Full thrust is NOT applied during FIGHTING.

### State machine
- **D-04:** States used: IDLING → SEEKING → FIGHTING → FLEEING → SEEKING (cycle).
- **D-05:** SEEKING → FIGHTING: player is within `fight_range` AND outside `comfort_range` (the Sniper is in the sweet spot). Transition to FIGHTING.
- **D-06:** FIGHTING → FLEEING: player moves inside `flee_range`. Stop firing, start retreating.
- **D-07:** SEEKING ↔ comfort band: if player enters `comfort_range` while in SEEKING or FIGHTING, apply reverse thrust. This is within-state behavior, not a state transition — keep current state, just change force direction.
- **D-08:** FLEEING → SEEKING: player moves outside a `safe_range` threshold (e.g. ~700px — between `fight_range` and `comfort_range` or slightly above `fight_range`). Transition back to SEEKING.

### Fire behavior — telegraph
- **D-09:** Aim-up pause before each shot. When the Sniper enters FIGHTING and fire timer triggers, it enters an "aiming" sub-phase: tracks/rotates toward the player for ~1 second without firing, then releases the shot. This creates a readable danger window for the player to dodge.
- **D-10:** Aim-up duration is an `@export var aim_up_time: float` (default ~1.0s). During aim-up, the Sniper continues reduced-thrust standoff movement.
- **D-11:** One shot per fire cycle (no spread, no burst). Single slow projectile.

### Sniper bullet
- **D-12:** New `sniper-bullet.tscn` — a structural copy of `beeliner-bullet.tscn` (which itself is a copy of `minigun-bullet.tscn`). Located at `prefabs/enemies/sniper/sniper-bullet.tscn`.
- **D-13:** Bullet is visually distinct from Beeliner shot — slower travel speed, higher `Damage.energy` value. Leave Sprite2D blank for now (same as Beeliner — user will provide art later).
- **D-14:** Bullet spawning follows established pattern: `spawn_parent.add_child(bullet)` at `$Barrel.global_position` (ENM-05).

### Scene inheritance
- **D-15:** `sniper.tscn` inherits `base-enemy-ship.tscn`. Only overrides: `@export` values and Fire Timer configuration. No structural changes.
- **D-16:** No picker `Area2D` in the Sniper scene (inherited base already omits it — ENM-15).

### Claude's Discretion
- Exact values for `fight_range`, `comfort_range`, `flee_range`, `safe_range` (export vars, tune in playtesting)
- Exact fire rate (fire timer interval) — should feel slow/deliberate relative to Beeliner's 1.5s burst
- Exact bullet speed and `Damage.energy` — slower and heavier than Beeliner, exact values for playtesting
- Reduced-thrust multiplier while in FIGHTING (e.g. 0.3× of normal thrust)
- Loot drop table — follow Beeliner pattern (coins + ammo, configured in ItemDropper)
- Sniper bullet sprite — leave blank; user will provide asset later

</decisions>

<specifics>
## Specific Ideas

- Two-range band creates the distinctive "sniper feel": Sniper never charges, always repositions to a precise zone, backs away if threatened.
- Aim-up telegraph (~1s) gives the player a skill test: recognizing the pre-fire pause and sidestepping.
- Reduced thrust (not zero) during FIGHTING keeps the Sniper from being a sitting duck — it drifts and corrects while aiming.
- FLEEING recovery is pure distance-based: once the player is far enough away, Sniper returns to SEEKING and repositions.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — ENM-08: full acceptance criteria for Phase 6
- `.planning/ROADMAP.md` §Phase 6 — Goal, success criteria, and phase boundary

### Base class (read before extending)
- `components/enemy-ship.gd` — Full EnemyShip base class: State enum, `_change_state`, `steer_toward`, `_integrate_forces` max_speed clamp, dying guard, detection wiring
- `prefabs/enemies/base-enemy-ship.tscn` — Scene to inherit from

### Concrete type reference (read the Beeliner — this is the closest implementation pattern)
- `components/beeliner.gd` — Full implementation pattern to replicate for Sniper: `_tick_state`, `_enter_state`, `_exit_state`, fire timer, bullet spawning
- `prefabs/enemies/beeliner/` — Beeliner scene + bullet scene structure to copy for Sniper

### Established patterns
- `components/item-dropper.gd` — Loot drop configuration (follow Beeliner pattern)
- `components/bullet.gd` — Bullet class used by all enemy bullets

### Physics layers
- `world.gd` lines 28–36 — Physics layer table — Sniper bullet must be on layer 3 (Bullets), masked to hit Ship (1)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `EnemyShip.steer_toward(target_position)` — applies `apply_central_force` toward target; Sniper uses the same helper for approach, and applies reverse direction for backing away
- `EnemyShip._change_state()` — handles exit/enter/print; Sniper calls this directly
- `Body.spawn_parent` — already propagates; Sniper bullet spawning uses this

### Established Patterns
- Beeliner's fire timer pattern: `_fire_timer.start()` in `_enter_state(FIGHTING)`, `_fire_timer.stop()` in `_exit_state(FIGHTING)` — Sniper adds an aim-up Timer on top of this
- Reverse thrust: apply `steer_toward` with the OPPOSITE target (away from player) using `-direction * thrust` or `steer_toward(global_position + away_vector)`
- `@export` for all tunable values — planner should include exports for all four range thresholds and aim_up_time

### Integration Points
- `world.gd`: WaveManager wave composition array — Sniper scene gets added as a second entry in the `waves` array for testing
- No other world.gd changes needed (wave trigger key already exists from Phase 5)

</code_context>

<deferred>
## Deferred Ideas

- Sniper sprite — user will provide asset later; use debug `_draw` placeholder inherited from EnemyShip
- Predictive targeting (leading the shot) — deferred to v2.1+ (in REQUIREMENTS.md)

</deferred>

---

*Phase: 06-sniper*
*Context gathered: 2026-04-12*
