---
plan: 06-01
phase: 6
subsystem: enemy-ai
tags: [enemy, sniper, ai, state-machine, bullet]
dependency_graph:
  requires: [components/enemy-ship.gd, components/enemy-bullet.gd, prefabs/enemies/beeliner/beeliner-bullet.tscn]
  provides: [components/sniper.gd, prefabs/enemies/sniper/sniper-bullet.tscn]
  affects: [world.gd]
tech_stack:
  added: []
  patterns: [extends-enemyship, two-timer-fire-pattern, distance-band-ai]
key_files:
  created:
    - components/sniper.gd
    - prefabs/enemies/sniper/sniper-bullet.tscn
  modified: []
decisions:
  - "Innermost-range-first check order in _tick_state (flee_range before comfort_range before fight_range) — Research Pitfall 4 compliance"
  - "Two-timer fire pattern: _fire_timer triggers aim-up via _aim_timer, _aim_timer triggers _fire() — clean 1s telegraph without blocking state machine"
  - "FIGHTING_THRUST_MULT=0.3 applied to both comfort-band reverse thrust and corrective thrust in FIGHTING state"
  - "Both timers stopped on FLEEING entry AND FIGHTING exit to prevent phantom shots after state change"
metrics:
  duration: "~20 minutes"
  completed_date: "2026-04-12"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 6 Plan 01: Sniper Script + Bullet Scene Summary

## One-liner

Sniper enemy AI with three-band standoff distance management (fight=900/comfort=600/flee=300), two-timer aim-up telegraph (1s pause before shot), FLEEING state with safe_range recovery, and a heavy slow sniper-bullet (energy=20, mass=80, life=3.0).

## What Was Built

### Task 1 — Sniper AI script (components/sniper.gd) — commit 877ef54

Created the Sniper AI script extending EnemyShip. Key features:

- **Three distance bands**: `fight_range=900` (sweet spot), `comfort_range=600` (reverse thrust), `flee_range=300` (trigger FLEEING)
- **FLEEING recovery**: `safe_range=700` — returns to SEEKING once outside this distance
- **Two-timer fire pattern**: `_fire_timer` (repeating) triggers `_aim_timer` (one_shot, 1s) which triggers `_fire()` — implements the aim-up telegraph pause
- **Distance-aware thrust**: FIGHTING state uses `FIGHTING_THRUST_MULT=0.3` for gentle corrective thrust toward player (comfort band) or reverse thrust (when too close)
- **SEEKING state**: also applies reverse thrust when in comfort band without state change (D-07 compliance)
- **Timer cleanup**: both `_fire_timer` and `_aim_timer` stopped on FLEEING entry, FIGHTING exit, and die()
- **Single shot**: no SPREAD_ANGLES — Sniper fires one precise heavy projectile per cycle (D-11)
- **±20% variability** on thrust and max_speed via `randf_range(0.8, 1.2)` in `_ready()`

### Task 2 — Sniper bullet scene (prefabs/enemies/sniper/sniper-bullet.tscn) — commit a3d5803

Created the sniper bullet scene as a structural copy of beeliner-bullet.tscn with heavier stats:

- `energy = 20.0` — 4x Beeliner's 5.0 for heavy shot feel
- `mass = 80.0` — heavier than Beeliner's 50.0
- `life = 3.0` — longer than Beeliner's 2.0 (slower bullet needs longer range to reach targets)
- `CollisionShape2D`: `16x100` (slightly larger than Beeliner's `12x84`)
- Same `collision_layer=256`, `collision_mask=1` as Beeliner bullet

## Commits

| Task | Description | Hash |
|------|-------------|------|
| T01 | Add Sniper AI script | 877ef54 |
| T02 | Add sniper-bullet.tscn | a3d5803 |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `components/sniper.gd` references `$FireTimer` and `$AimTimer` as @onready vars — these nodes must be present in the sniper.tscn scene, which is created in plan 06-02. Until the scene exists, the script will error if instantiated directly.
- `prefabs/enemies/sniper/sniper-bullet.tscn` has an empty `Sprite2D` child — no texture art assigned yet. The `EnemyBullet._draw()` debug visual (orange circle + crosshair) will be visible until art is provided.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| components/sniper.gd exists | FOUND |
| prefabs/enemies/sniper/sniper-bullet.tscn exists | FOUND |
| commit 877ef54 exists | FOUND |
| commit a3d5803 exists | FOUND |
