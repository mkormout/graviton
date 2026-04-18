---
phase: 18-weapons-improvements
plan: "04"
subsystem: weapons/rpg
tags: [rpg, homing, lock-on, weapon]
dependency_graph:
  requires: [18-01]
  provides: [RpgWeapon, RpgBullet]
  affects: [prefabs/rpg/rpg.tscn, prefabs/rpg/rpg-bullet.tscn]
tech_stack:
  added: []
  patterns: [fire-override, cone-scan, deferred-child-access, per-frame-force-steering]
key_files:
  created:
    - prefabs/rpg/rpg-weapon.gd
    - prefabs/rpg/rpg-bullet.gd
  modified:
    - prefabs/rpg/rpg.tscn
    - prefabs/rpg/rpg-bullet.tscn
decisions:
  - "RpgWeapon._assign_bullet_target() uses call_deferred to safely access the bullet after add_child deferred completes"
  - "Lock fades at 2x speed (delta*2) when target leaves cone, giving partial persistence"
  - "fired_heavy signal emitted unconditionally on every fire (locked or not) for consistent camera shake"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-19"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 2
---

# Phase 18 Plan 04: RPG Homing Lock-On Summary

**One-liner:** RPG gains passive cone-scan lock-on (1.5s, 60deg) producing homing rockets via per-frame apply_central_force steering in RpgBullet.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create rpg-weapon.gd with cone lock acquisition | ad8f781 | prefabs/rpg/rpg-weapon.gd (created) |
| 2 | Modify rpg-bullet.gd to support homing steering | 2151194 | prefabs/rpg/rpg-bullet.gd (created), rpg-bullet.tscn, rpg.tscn (modified) |

## What Was Built

### RpgWeapon (prefabs/rpg/rpg-weapon.gd)
- Extends `MountableWeapon` with passive 60-degree cone scan every `_process` frame
- `LOCK_TIME=1.5s`, `CONE_ANGLE=PI/6` (30-degree half-angle), `LOCK_RANGE=3000` units
- `lock_progress` (0.0-1.0) and `lock_target` properties exposed for HUD (plan 18-10)
- Lock fades at 2x rate when target leaves cone; switches target immediately on new candidate
- `fired_heavy` signal emitted on every fire for camera shake integration
- After `super()` fires the bullet, `call_deferred("_assign_bullet_target")` safely routes the target reference to the spawned bullet
- `is_instance_valid()` guards on all stale reference paths (T-18-04-01 mitigated)

### RpgBullet (prefabs/rpg/rpg-bullet.gd)
- Extends `Bullet` (which extends `Body`/`RigidBody2D`)
- `set_target(t: Node2D)` called by RpgWeapon after fire when locked
- `_physics_process` applies `apply_central_force(dir * TURN_FORCE)` toward target each frame
- `is_instance_valid(_target)` guard: rocket continues in current direction when target dies — no crash (T-18-04-01, D-11 behavior)
- No `super._physics_process()` needed — `Bullet` has no `_physics_process`

### Scene Updates
- `rpg.tscn`: script updated from `components/mountable-weapon.gd` to `prefabs/rpg/rpg-weapon.gd`
- `rpg-bullet.tscn`: script updated from `components/bullet.gd` to `prefabs/rpg/rpg-bullet.gd`

## Decisions Made

1. **Deferred target assignment:** `_assign_bullet_target()` runs via `call_deferred` to guarantee the bullet is in the scene tree (added via `spawn_parent.call_deferred("add_child", ...)`) before accessing `spawn_parent.get_children().back()`.

2. **Lock fade speed:** Lock fades at `delta * 2.0` (twice the build rate) when target leaves cone — gives a brief grace period if target briefly exits cone.

3. **Unconditional `fired_heavy` emit:** Signal fires on every RPG shot (locked or not) to ensure consistent camera shake behavior regardless of lock state.

4. **No UID in scene edits:** When updating .tscn ext_resource entries for new scripts (not yet registered in the project), the `uid=` field was omitted — Godot will assign a UID on next editor open.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] Updated rpg.tscn script reference to RpgWeapon**
- **Found during:** Task 2 review
- **Issue:** The plan's success criteria explicitly required `rpg.tscn` script to be updated to `rpg-weapon.gd`, but no task explicitly listed `rpg.tscn` in its `<files>` tag.
- **Fix:** Updated `rpg.tscn` ext_resource script path from `mountable-weapon.gd` to `rpg-weapon.gd` as part of Task 2 commit.
- **Files modified:** prefabs/rpg/rpg.tscn
- **Commit:** 2151194

## Known Stubs

None — both classes are fully wired. `lock_progress` and `lock_target` are real computed properties (not placeholders); HUD wiring is deferred to plan 18-10 by design.

## Threat Flags

No new security-relevant surface beyond what was planned in the threat model.

## Self-Check: PASSED

- prefabs/rpg/rpg-weapon.gd: FOUND
- prefabs/rpg/rpg-bullet.gd: FOUND
- prefabs/rpg/rpg.tscn (updated): FOUND
- prefabs/rpg/rpg-bullet.tscn (updated): FOUND
- Commit ad8f781: FOUND (feat(18-04): create RpgWeapon with cone lock acquisition)
- Commit 2151194: FOUND (feat(18-04): add RpgBullet homing steering and update scene script refs)
