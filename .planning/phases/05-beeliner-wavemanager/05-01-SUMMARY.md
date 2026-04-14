---
phase: 05-beeliner-wavemanager
plan: 01
subsystem: enemy-ai
tags: [gdscript, godot4, enemy, state-machine, beeliner, item-dropper]

requires:
  - phase: 04-enemyship-infrastructure
    provides: "EnemyShip base class with State enum, _tick_state/_enter_state/_exit_state virtuals, steer_toward, detection area, hitbox, Barrel node, base-enemy-ship.tscn"

provides:
  - "Beeliner concrete enemy type (beeliner.gd) extending EnemyShip with SEEKING/FIGHTING state machine"
  - "3-bullet shotgun burst fire at -7.5/0/+7.5 degree spread via FireTimer (1.5s)"
  - "beeliner-bullet.tscn projectile (energy=5.0, collision_layer=4/mask=8)"
  - "beeliner.tscn scene with CoinDropper (2x copper coins) and AmmoDropper (50% minigun-ammo)"

affects: [05-02-wavemanager, future-enemy-types]

tech-stack:
  added: []
  patterns:
    - "Flat .tscn scene for enemies — duplicates base-enemy-ship node hierarchy rather than Godot scene inheritance"
    - "Dual ItemDropper pattern — Body.item_dropper export for primary drops, second dropper called manually in die() override"
    - "spawn_parent.add_child for bullet spawning — no get_tree().current_scene (follows ENM-05)"
    - "Dying guard at top of _fire() and timer callbacks prevents post-death bullet spawning"

key-files:
  created:
    - components/beeliner.gd
    - prefabs/enemies/beeliner/beeliner-bullet.tscn
    - prefabs/enemies/beeliner/beeliner.tscn
  modified: []

key-decisions:
  - "Flat scene for beeliner.tscn instead of true Godot scene inheritance — avoids inheritance-related .tscn complications while still referencing base-enemy-ship.tscn as an ext_resource"
  - "Immediate _fire() call in _enter_state(FIGHTING) so first burst fires on state transition, not after 1.5s delay"
  - "Dual ItemDropper nodes: CoinDropper wired to Body.item_dropper export (called automatically on die), AmmoDropper called manually in die() override"

patterns-established:
  - "Enemy bullet scenes: mirror minigun-bullet.tscn structure with energy-based Damage resource; reuse minigun-bullet-explosion.tscn for death visual"
  - "Enemy loot: two ItemDropper nodes for independent drop tables per loot category"

requirements-completed: [ENM-07]

duration: 20min
completed: 2026-04-12
---

# Phase 05 Plan 01: Beeliner Enemy Summary

**Beeliner concrete enemy type with SEEKING->FIGHTING state machine, 3-bullet shotgun burst fire (1.5s timer), and dual ItemDropper loot (2 copper coins + 50% minigun-ammo chance)**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-12T09:00:00Z
- **Completed:** 2026-04-12T09:20:00Z
- **Tasks:** 2
- **Files modified:** 3 created

## Accomplishments
- Created `beeliner-bullet.tscn` — energy-based projectile (energy=5.0, kinetic=0.0) with correct collision layers (4/8) and reused explosion visual
- Created `beeliner.gd` — extends EnemyShip, implements SEEKING/FIGHTING states, 3-bullet shotgun burst at ±7.5 degrees, dying guards in all fire paths, spawn_parent.add_child bullet spawning
- Created `beeliner.tscn` — full scene with FireTimer (1.5s), CoinDropper (2x guaranteed copper coins), AmmoDropper (50% minigun-ammo), referencing base-enemy-ship.tscn

## Task Commits

Each task was committed atomically:

1. **Task 1: Create beeliner-bullet.tscn scene** - `743df8a` (feat)
2. **Task 2: Create beeliner.gd script and beeliner.tscn inherited scene** - `78e3cb1` (feat)

**Plan metadata:** (committed with SUMMARY below)

## Files Created/Modified
- `components/beeliner.gd` — Beeliner class extending EnemyShip: SEEKING/FIGHTING state machine, shotgun burst fire, target tracking, die() override for ammo drops
- `prefabs/enemies/beeliner/beeliner-bullet.tscn` — Bullet scene with Bullet script, Damage(energy=5.0), collision_layer=4, collision_mask=8
- `prefabs/enemies/beeliner/beeliner.tscn` — Enemy scene with FireTimer, CoinDropper, AmmoDropper nodes; references base-enemy-ship.tscn and beeliner.gd

## Decisions Made
- Used flat scene (not Godot inherited scene) for `beeliner.tscn` — duplicates node hierarchy from base-enemy-ship rather than using Godot scene inheritance. Still references `base-enemy-ship.tscn` as an ext_resource. This avoids .tscn inheritance format complexity while keeping the structural intent clear.
- First burst fires immediately on `_enter_state(FIGHTING)` before timer starts — avoids the UX problem of a 1.5s delay before the enemy fires on first engagement.
- `AmmoDropper.drop()` called manually in overridden `die()` so it fires regardless of whether Body.item_dropper is set. CoinDropper is wired to `Body.item_dropper` export for automatic calling.

## Deviations from Plan

None - plan executed exactly as written. All threat mitigations (T-05-01 through T-05-04) implemented as specified: dying guards, state checks, type checks in detection handler.

## Issues Encountered
- Worktree was based on older commit; required `git reset --soft` and `git checkout HEAD -- .` to restore correct working tree state before execution.

## Known Stubs
None — no placeholder values, all data wired (drop tables reference real PackedScene paths for coin-copper and minigun-ammo).

## Next Phase Readiness
- `beeliner.tscn` is ready to be spawned by WaveManager (Plan 02)
- `spawn_parent` must be set on the Beeliner node when instantiated by WaveManager
- Scene path for WaveManager to reference: `res://prefabs/enemies/beeliner/beeliner.tscn`

---
*Phase: 05-beeliner-wavemanager*
*Completed: 2026-04-12*
