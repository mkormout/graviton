---
phase: 18-weapons-improvements
plan: "07"
subsystem: weapons/vfx
tags: [muzzle-flash, cpuparticles2d, laser-weapon, visual-feedback]
dependency_graph:
  requires: [18-03, 18-04, 18-05, 18-06]
  provides: [muzzle-flash-on-all-weapons]
  affects: [gausscannon.tscn, rpg.tscn, minigun.tscn, gravitygun.tscn, laser.tscn]
tech_stack:
  added: [LaserWeapon class]
  patterns: [CPUParticles2D one_shot restart() per-fire burst, null-guarded @export node binding]
key_files:
  created:
    - prefabs/laser/laser-weapon.gd
  modified:
    - prefabs/gausscannon/gausscannon-weapon.gd
    - prefabs/gausscannon/gausscannon.tscn
    - prefabs/rpg/rpg-weapon.gd
    - prefabs/rpg/rpg.tscn
    - prefabs/minigun/minigun-weapon.gd
    - prefabs/minigun/minigun.tscn
    - prefabs/gravitygun/gravitygun-script.gd
    - prefabs/gravitygun/gravitygun.tscn
    - prefabs/laser/laser.tscn
decisions:
  - "muzzle_flash.restart() called after bullet spawn (not before) so flash coincides with projectile appearance"
  - "GravityGun and Gausscannon flash fires in _fire_charged() not fire(), matching charge-release pattern"
  - "laser.tscn script replaced from base mountable-weapon.gd to new laser-weapon.gd to enable fire() override hook"
metrics:
  duration: ~8 minutes
  completed: 2026-04-19
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 9
---

# Phase 18 Plan 07: Muzzle Flash VFX on All Weapons Summary

**One-liner:** Per-weapon CPUParticles2D muzzle flash burst wired into all five weapon fire() methods via null-guarded restart() calls with distinct per-weapon colors.

## What Was Built

Added visible muzzle flash feedback to all five weapons in the game. Each weapon now emits a short burst of particles at its barrel position on every fire event, with colors tuned to match each weapon's visual style.

**LaserWeapon (new script):** `prefabs/laser/laser-weapon.gd` — `LaserWeapon extends MountableWeapon` with `@export var muzzle_flash: CPUParticles2D` and a `fire()` override that calls `muzzle_flash.restart()` then `super()`. The laser scene previously used the base `MountableWeapon` directly with no script override hook; this new class provides the needed extension point.

**Per-weapon flash colors and parameters:**

| Weapon | Color | Amount | Lifetime | Spread |
|--------|-------|--------|----------|--------|
| Minigun | Color(1.0, 0.8, 0.2) yellow-orange | 6 | 0.1s | 20° |
| Gausscannon | Color(0.4, 0.7, 1.0) blue-white | 10 | 0.15s | 25° |
| RPG | Color(1.0, 0.5, 0.1) orange | 15 | 0.2s | 35° |
| Laser | Color(0.2, 1.0, 0.2) bright green | 8 | 0.12s | 15° |
| GravityGun | Color(0.2, 1.0, 0.4) green-teal | 12 | 0.25s | 45° |

All nodes: `one_shot = true`, `emitting = false` (start inactive), `explosiveness = 0.85–0.95`.

**Fire hook placement:**
- Minigun: `fire()` after `add_child` (deferred)
- RPG: `fire()` after `super()`
- Gausscannon: `_fire_charged()` after bullet `add_child`
- GravityGun: `_fire_charged()` before `fired_heavy.emit()`
- Laser: `fire()` before `super()` (restart → then super fires bullet)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | efa0345 | feat(18-07): add muzzle_flash export and restart() to all weapon scripts |
| Task 2 | e93fb73 | feat(18-07): add MuzzleFlash CPUParticles2D to all 5 weapon scenes |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes. CPUParticles2D nodes are purely visual, client-side, and self-contained. T-18-07-01 (null guard) and T-18-07-02 (one_shot accumulation) mitigations confirmed present.

## Known Stubs

None — all muzzle flash nodes are fully wired with NodePath bindings. No placeholder data.

## Self-Check: PASSED

- `prefabs/laser/laser-weapon.gd` — FOUND
- Commit `efa0345` — FOUND
- Commit `e93fb73` — FOUND
- MuzzleFlash nodes in all 5 scenes — FOUND (verified via grep)
- `one_shot = true` on all 5 MuzzleFlash nodes — FOUND
- `laser-weapon.gd` reference in laser.tscn — FOUND
- `muzzle_flash.restart()` in all 5 weapon scripts — FOUND (2+ matches each)
