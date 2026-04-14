---
phase: 09-suicider
plan: "01"
subsystem: enemy-ai
tags: [enemy, suicider, explosion, ai, state-machine]
dependency_graph:
  requires:
    - components/enemy-ship.gd
    - components/explosion.gd
    - components/body.gd
    - components/swarmer.gd
  provides:
    - components/suicider.gd
    - prefabs/enemies/suicider/suicider-explosion.tscn
  affects:
    - components/explosion.gd
tech_stack:
  added:
    - Suicider class extending EnemyShip
  patterns:
    - Locked-vector torpedo mechanic (snapshot position at state entry)
    - ContactArea2D for contact-triggered die()
    - Overshoot detection via linear_velocity.dot()
    - Thrust ramp via clampf on distance ratio
    - Backward-compatible hit_ships export on Explosion
key_files:
  created:
    - components/suicider.gd
    - prefabs/enemies/suicider/suicider-explosion.tscn
  modified:
    - components/explosion.gd
decisions:
  - "Used _reacquire_target() instead of _change_state(State.SEEKING) for re-lock to bypass EnemyShip idempotency guard (line 53)"
  - "hit_ships export defaults to false — backward-compatible; only suicider-explosion sets true"
  - "ContactArea2D rather than DetectionArea for contact detection — separate concern from target acquisition"
metrics:
  duration: "2 minutes"
  completed_date: "2026-04-13"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 9 Plan 1: Suicider Script + Explosion Summary

**One-liner:** Suicider AI with locked-vector torpedo mechanic, ContactArea2D contact detonation, and devastating explosion (radius=450, energy=350, kinetic=100, hit_ships=true) patched via backward-compatible explosion.gd export.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create suicider.gd script | 8aaa215 | components/suicider.gd (new) |
| 2 | Patch explosion.gd + create suicider-explosion.tscn | e5157b8 | components/explosion.gd (modified), prefabs/enemies/suicider/suicider-explosion.tscn (new) |

## What Was Built

### Task 1: suicider.gd

Suicider AI script extending EnemyShip. Uses only IDLING and SEEKING states — no FIGHTING, FLEEING, or LURKING.

**Locked-vector torpedo mechanic (D-01 through D-03):**
- `_enter_state(State.SEEKING)` snapshots `_target.global_position` into `_locked_target_pos` once
- Suicider does NOT track live player position — it flies to where the player was when it detected them
- Overshoot detection: `linear_velocity.dot(to_locked) < 0.0` triggers `_reacquire_target()` which re-snapshots current player position
- `_reacquire_target()` bypasses the `_change_state()` idempotency guard (EnemyShip line 53 returns early when `new_state == current_state`)

**Thrust ramp (D-02):** `clampf(1.0 + (1.0 - dist / detection_radius), 1.0, 2.0)` — thrust scales up as the Suicider closes distance, creating accelerating torpedo behavior.

**ContactArea2D (D-04, D-06):** Dedicated `$ContactArea` with `dying` guard. When PlayerShip enters the contact area, `die()` is called immediately. The `dying` flag prevents double-fire.

**Minimal die() override (D-11, D-12):** No FireTimer to stop, no ItemDropper/AmmoDropper to call. Just `super(delay)`.

### Task 2: explosion.gd patch + suicider-explosion.tscn

**explosion.gd patch (A1 critical finding):** Added `@export var hit_ships: bool = false`. When true, `initialize()` conditionally adds `area.set_collision_mask_value(1, true)` after the existing mask setup. The original `set_collision_mask_value(1, false)` line is preserved — existing explosions are unaffected.

**suicider-explosion.tscn:** Located at `prefabs/enemies/suicider/suicider-explosion.tscn`. Configured for devastating contact detonation:
- `radius = 450.0` — large enough to punish near-misses
- `power = 10000` — 10x asteroid explosion, visibly launches player
- `attack`: `energy = 350.0`, `kinetic = 100.0` (near-lethal damage)
- `hit_ships = true` — enables PlayerShip detection via shockwave
- CPUParticles2D: 500 particles, scale=5x, orange-red fireball (asteroid gradient)
- PointLight2D: orange-yellow `Color(1, 0.7, 0.1, 1)`, energy=2.0, texture_scale=30
- RandomAudioPlayer: all four explosion wav files

## Deviations from Plan

None — plan executed exactly as written. Both tasks completed per specification.

## Threat Model Coverage

| Threat | Mitigation | Status |
|--------|-----------|--------|
| T-09-01: ContactArea2D double-trigger | `if dying: return` in `_on_contact_area_body_entered` | Implemented |
| T-09-02: Re-acquisition infinite loop | `_reacquire_target()` does not call `_change_state`; overshoot check requires `length_squared() > 100.0` | Implemented |
| T-09-03: Explosion damages wrong targets | `hit_ships` defaults false; only suicider-explosion sets true | Implemented |
| T-09-04: Explosion self-damage | Accepted — Suicider already dying before Area2D evaluates | Accepted |

## Known Stubs

None — no placeholder values or TODO markers in created/modified files.

## Self-Check: PASSED

- `components/suicider.gd` exists: FOUND
- `prefabs/enemies/suicider/suicider-explosion.tscn` exists: FOUND
- Commit 8aaa215 exists: FOUND
- Commit e5157b8 exists: FOUND
