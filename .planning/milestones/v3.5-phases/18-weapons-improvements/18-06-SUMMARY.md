---
phase: 18-weapons-improvements
plan: "06"
subsystem: weapons
tags: [gravitygun, charge-mechanic, hold-to-fire, pointlight2d, camera-shake]
dependency_graph:
  requires: [18-01]
  provides: [gravitygun-charge, fired-heavy-signal]
  affects: [world.gd, components/body_camera.gd]
tech_stack:
  added: []
  patterns: [hold-to-charge, area-scale-restore, lerped-sine-pulse]
key_files:
  created: []
  modified:
    - prefabs/gravitygun/gravitygun-script.gd
    - prefabs/gravitygun/gravitygun.tscn
decisions:
  - Use existing PointLight2D in scene rather than adding ChargeLight — avoids scene duplication
  - _fire_charged() handles ammo/rate/sound directly (no super() call) since MountableWeapon.fire() spawns a projectile bullet, which GravityGun does not use
  - area.scale and strength both restored after await 0.1s delay to honour threat T-18-06-01
metrics:
  duration: "~10 minutes"
  completed: "2026-04-19"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
---

# Phase 18 Plan 06: GravityGun Hold-to-Charge Summary

GravityGun rewritten with hold-to-charge mechanic: shockwave force and area radius scale 1x–2.5x with charge fraction, PointLight2D pulses faster as charge builds via lerped sine frequency, and fired_heavy signal emitted for future camera shake hookup.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add charge mechanic to gravitygun-script.gd | 548e39b | prefabs/gravitygun/gravitygun-script.gd |
| 2 | Add PointLight2D light export binding to gravitygun.tscn | 204c17c | prefabs/gravitygun/gravitygun.tscn |

## What Was Built

**Task 1 — gravitygun-script.gd:**
- `CHARGE_MAX = 1.5` seconds max charge; `STRENGTH_MIN/MAX_MULT = 1.0/2.5`; `AREA_MIN/MAX_MULT = 1.0/2.5`
- `charge_current` accumulates each physics frame while `ui_select` held and `can_shoot()` true
- `_fire_charged()` called on release: scales `area.scale` and `strength` by charge fraction, calls `apply_damage()` + `apply_kickback()`, then restores both (threat T-18-06-01 mitigated)
- `_process()` sets `light.energy` via lerped sine wave with frequency scaling from 2–12 rad/s as charge builds
- `do()` overrides parent; intentionally does NOT forward `Action.FIRE` — charge is self-managed
- `get_charge_fraction()` exposed for Weapon HUD (plan 18-09)
- `signal fired_heavy` declared; emitted after each charged fire for camera shake (plan 18-10)

**Task 2 — gravitygun.tscn:**
- Existing `PointLight2D` node (already in scene at position 110, 0) referenced via new `light = NodePath("PointLight2D")` @export binding
- `"light"` added to `node_paths` PackedStringArray on root node so Godot resolves it correctly

## Deviations from Plan

### Auto-adapted Issues

**1. [Rule 2 - Adaptation] Used existing PointLight2D instead of adding new ChargeLight**
- **Found during:** Task 2 read of gravitygun.tscn
- **Issue:** A `PointLight2D` node already existed in the scene at line 69. Adding a second `ChargeLight` would be redundant.
- **Fix:** Wired existing `PointLight2D` via `light = NodePath("PointLight2D")`. The plan explicitly states "If a PointLight2D already exists in the scene, note its node name and skip adding a new one."
- **Files modified:** prefabs/gravitygun/gravitygun.tscn
- **Commit:** 204c17c

**2. [Rule 1 - Bug Prevention] _fire_charged() calls ammo/rate/sound directly instead of super()**
- **Found during:** Task 1 implementation
- **Issue:** `MountableWeapon.fire()` instantiates a bullet `PackedScene` at the barrel position. Calling `super()` in GravityGun would spawn an unwanted bullet on each charged shot.
- **Fix:** `_fire_charged()` handles `shot_timer.start(rate)`, `magazine_current -= 1`, and `sound.play()` directly — preserving the accounting without triggering projectile spawn. This matches the original `GravityGun.fire()` pattern which also called `super()` then immediately applied area effects; the new version skips `super()` entirely to avoid projectile.
- **Files modified:** prefabs/gravitygun/gravitygun-script.gd
- **Commit:** 548e39b

## Known Stubs

None — charge logic is fully wired. The `fired_heavy` signal is emitted but not yet connected to camera shake; connection is deferred to plan 18-10 as documented in the plan's `key_links`.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `fired_heavy` signal is an intra-scene signal — no cross-boundary surface.

## Self-Check: PASSED

- [x] `prefabs/gravitygun/gravitygun-script.gd` exists and contains `CHARGE_MAX: float = 1.5`, `signal fired_heavy`, `func get_charge_fraction`
- [x] `prefabs/gravitygun/gravitygun.tscn` contains `PointLight2D` and `light = NodePath(...)`
- [x] Commit 548e39b exists (Task 1)
- [x] Commit 204c17c exists (Task 2)
- [x] `Action.FIRE` NOT present in gravitygun-script.gd do() handler
- [x] `area.scale` restored after `await` in `_fire_charged()` (T-18-06-01 mitigated)
