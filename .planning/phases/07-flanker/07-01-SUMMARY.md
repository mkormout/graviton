---
phase: 07-flanker
plan: "01"
subsystem: enemy-ai
tags: [flanker, orbital-ai, state-machine, gdscript, enemy-bullet]
dependency_graph:
  requires: [components/enemy-ship.gd, components/enemy-bullet.gd, prefabs/minigun/minigun-bullet-explosion.tscn]
  provides: [components/flanker.gd, prefabs/enemies/flanker/flanker-bullet.tscn]
  affects: [prefabs/enemies/flanker/flanker.tscn (07-02)]
tech_stack:
  added: []
  patterns: [tangential-radial-orbit-force, fire-timer-pattern, beeliner-die-pattern, sniper-body-exited-pattern]
key_files:
  created:
    - components/flanker.gd
    - prefabs/enemies/flanker/flanker-bullet.tscn
  modified: []
decisions:
  - "orbit_direction randomized 50/50 CW vs CCW in _ready() per D-18"
  - "look_at(global_position + tangential) in LURKING so barrel faces direction of travel, not player (Pattern 2)"
  - "fight_range=4500 < orbit_radius=7000 < return_range=7500 — safe hysteresis gap prevents oscillation"
  - "orbit_correction_strength=0.15 as starting point for P-controller tuning in inspector"
metrics:
  duration_seconds: 150
  completed_date: "2026-04-12"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 07 Plan 01: Flanker Script + Bullet Scene Summary

**One-liner:** Flanker AI with tangential+radial orbital force LURKING state, rapid-fire FIGHTING state, and enemy-bullet.gd-backed projectile scene.

## What Was Built

### Task 1: components/flanker.gd

Flanker AI script implementing the orbital state machine. Key behaviors:

- **SEEKING state:** `look_at` + `steer_toward` target; transitions to LURKING when within `orbit_entry_range` (9500).
- **LURKING state:** Orbital motion using `Vector2.orthogonal()` for tangential force plus a proportional radial correction P-controller (`orbit_correction_strength=0.15`). Faces direction of travel via `look_at(global_position + tangential)`. No firing. Transitions to FIGHTING when `dist < fight_range` (4500).
- **FIGHTING state:** `look_at` player + `steer_toward` + fire timer loop. Transitions back to LURKING when `dist > return_range` (7500). Hysteresis gap (4500 < 7500) prevents oscillation.
- **_ready():** Per-instance randomization of `orbit_direction` (CW/CCW), `orbit_radius` (±30%), `thrust` and `max_speed` (±20%).
- **die():** Stop fire timer + `_ammo_dropper.drop()` + `super()`. Identical pattern to Beeliner/Sniper.
- **Target management:** `body_exited` only clears `_target` in SEEKING state (Sniper pattern). `is_instance_valid()` guard in `_tick_state` handles stale references in other states.

### Task 2: prefabs/enemies/flanker/flanker-bullet.tscn

Structural copy of `sniper-bullet.tscn` with reduced values for rapid-fire use:
- `energy=5.0` (vs Sniper 20.0) — lower per-shot for burst fire pattern
- `mass=30.0` (vs Sniper 80.0) — lighter bullet
- `life=2.0` (vs Sniper 5.0) — short-range combat
- `CollisionShape2D size=Vector2(10,70)` (vs 16x100) — smaller bullet
- Same `collision_layer=256`, `collision_mask=1` as all enemy bullets
- Script: `enemy-bullet.gd` (EnemyShip self-hit guard included)
- Death: shared `minigun-bullet-explosion.tscn`

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria met.

## Threat Mitigations Applied

Per threat model:
- **T-07-01 (DoS — runaway bullets):** `_on_fire_timer_timeout()` guard `if dying or current_state != State.FIGHTING: return` prevents firing outside FIGHTING state. `if dying: return` in `_fire()` adds defense in depth.

## Known Stubs

None. Both files are complete implementations ready for scene integration in 07-02.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundaries introduced. Bullet collision layers match existing enemy bullet conventions.

## Self-Check: PASSED

- `components/flanker.gd` — FOUND
- `prefabs/enemies/flanker/flanker-bullet.tscn` — FOUND
- Commit `134854b` (Task 1 - Flanker AI script) — FOUND
- Commit `136471d` (Task 2 - Flanker bullet scene) — FOUND
