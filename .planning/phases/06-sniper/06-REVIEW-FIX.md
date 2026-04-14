---
phase: 06-sniper
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/06-sniper/06-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** .planning/phases/06-sniper/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (CR-01, WR-01, WR-02, WR-03, WR-04)
- Fixed: 4
- Skipped: 1

## Fixed Issues

### CR-01: FireTimer/AimTimer overlap guard

**Files modified:** `components/sniper.gd`
**Commit:** bafbfcf
**Applied fix:** Added `assert(aim_up_time < _fire_timer.wait_time, ...)` in `_enter_state` immediately before `_fire_timer.start()`. If `aim_up_time` is ever misconfigured to be >= the fire interval, the assertion fires in debug builds and makes the bug immediately visible rather than silently swallowing all shots.

---

### WR-01: Bullet spawned from Barrel node position

**Files modified:** `components/sniper.gd`
**Commit:** 65a57e6
**Applied fix:** Added `@onready var _barrel: Node2D = $Barrel` and replaced `global_position + fire_dir * 350.0` in `_fire()` with `_barrel.global_position`. Bullets now originate from the Barrel node's actual world position, consistent with the scene design intent. The old hardcoded 350-unit comment was removed since the Barrel node encodes the correct offset directly.

---

### WR-02: _target validity guard and body_exited handler

**Files modified:** `components/sniper.gd`
**Commit:** 6170179
**Applied fix:** Three changes:
1. Connected `detection_area.body_exited` to `_on_detection_area_body_exited` in `_ready()`.
2. Added `_on_detection_area_body_exited` handler that clears `_target` and returns sniper to IDLING when the tracked player body leaves the detection area.
3. Replaced `if not _target:` guard in `_tick_state` with `if not is_instance_valid(_target):` which safely handles freed objects, then clears `_target` and transitions to IDLING to avoid using a dangling reference.

---

### WR-03: SEEKING comfort-band thrust damped by velocity direction

**Files modified:** `components/sniper.gd`
**Commit:** 0d1c39d
**Applied fix:** Replaced the unconditional `apply_central_force(away * thrust)` in the SEEKING comfort-band with a velocity-dot-product check: `var vel_toward := linear_velocity.dot(toward); if vel_toward > 0: apply_central_force(away * thrust)`. Thrust is now applied only when the sniper is actually drifting toward the player, which prevents the runaway oscillation caused by applying repulsive force every frame regardless of current motion direction.

---

## Skipped Issues

### WR-04: CoinDropper never fires

**File:** `prefabs/enemies/sniper/sniper.tscn:38`, `components/sniper.gd:114-120`
**Reason:** Finding does not apply — coins are already dropped correctly via the base class. `Body.die()` (lines 54-55) calls `item_dropper.drop()` when `item_dropper` is set. The sniper scene sets `item_dropper = NodePath("CoinDropper")` on the root node. `Sniper.die()` calls `super(delay)` which routes to `Body.die()`, which calls `CoinDropper.drop()`. No code change needed; adding an explicit `$CoinDropper.drop()` call in `Sniper.die()` would cause CoinDropper to fire twice per death.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
