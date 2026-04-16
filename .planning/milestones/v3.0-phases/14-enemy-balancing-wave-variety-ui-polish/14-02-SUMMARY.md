---
phase: 14-enemy-balancing-wave-variety-ui-polish
plan: "02"
subsystem: enemy-ai
tags: [enemy-ai, behavioral-tweaks, beeliner, sniper, flanker, swarmer]
one_liner: "Per-enemy behavioral tweaks: Beeliner perpendicular jitter, Sniper sinusoidal strafe, Flanker patrol-resume fix, Swarmer speed-tier export"

dependency_graph:
  requires: []
  provides:
    - "Beeliner jitter_force export and perpendicular weave logic in SEEKING and FIGHTING"
    - "Sniper strafe_force/strafe_period exports and sinusoidal strafe in FIGHTING"
    - "Flanker _on_detection_area_body_exited SEEKING-only guard (no freeze)"
    - "Swarmer speed_tier export applied before per-instance variance"
  affects:
    - "components/beeliner.gd"
    - "components/sniper.gd"
    - "components/flanker.gd"
    - "components/swarmer.gd"

tech_stack:
  added: []
  patterns:
    - "apply_central_force with perpendicular Vector2.from_angle(global_rotation + PI/2) for lateral forces"
    - "Sinusoidal strafe via sin(time * TAU / period) multiplied by perpendicular vector"
    - "State-gated detection exit handler (only act in SEEKING, not LURKING/FIGHTING)"
    - "Multiplicative speed_tier export applied before random variance in _ready()"

key_files:
  modified:
    - components/beeliner.gd
    - components/sniper.gd
    - components/flanker.gd
    - components/swarmer.gd
  created: []

decisions:
  - "Jitter timer and direction are shared between SEEKING and FIGHTING states rather than reset on state transition — ensures continuous weave without teleporting"
  - "Sniper _strafe_time resets to 0.0 on FIGHTING entry to keep oscillation phase predictable"
  - "speed_tier multiplied before randf_range variance so tier scales the base, not the variance band"

metrics:
  duration_seconds: 76
  completed_date: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
  files_created: 0
---

# Phase 14 Plan 02: Enemy Behavioral Tweaks Summary

Per-enemy behavioral tweaks: Beeliner perpendicular jitter (D-13), Sniper sinusoidal strafe (D-14), Flanker patrol-resume bug fix (D-15), Swarmer speed-tier export (D-16).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Beeliner jitter and Sniper strafe behavioral logic | a86a717 | components/beeliner.gd, components/sniper.gd |
| 2 | Fix Flanker patrol resumption bug and add Swarmer speed tier export | 789edca | components/flanker.gd, components/swarmer.gd |

## What Was Built

### Task 1: Beeliner Jitter + Sniper Strafe

**beeliner.gd:** Added `@export var jitter_force: float = 300.0` and two instance vars (`_jitter_timer`, `_jitter_dir`). In `_tick_state`, both the SEEKING and FIGHTING branches now apply a perpendicular force using `Vector2.from_angle(global_rotation + PI / 2.0) * _jitter_dir * jitter_force`. The direction flips every 1–2 seconds via the timer. Force is inside the `if _target:` guard in both states.

**sniper.gd:** Added `@export var strafe_force: float = 200.0`, `@export var strafe_period: float = 4.0`, and `var _strafe_time: float = 0.0`. In `_tick_state`'s FIGHTING branch, `_strafe_time` accumulates each frame and drives `sin(_strafe_time * TAU / strafe_period)` as a multiplier for a perpendicular force. The strafe block is placed before the `if dist < flee_range:` range checks. `_enter_state` resets `_strafe_time = 0.0` before the existing assert.

### Task 2: Flanker Fix + Swarmer Speed Tier

**flanker.gd:** `_on_detection_area_body_exited` previously went IDLING unconditionally when the player left the detection radius. Fixed by adding `and current_state == State.SEEKING` to the condition — matching the established Sniper pattern. LURKING and FIGHTING states now retain their target and rely on the existing `max_follow_distance` leash in `_tick_state`.

**swarmer.gd:** Added `@export var speed_tier: float = 1.0`. In `_ready()`, inserted `thrust *= speed_tier` and `max_speed *= speed_tier` before the existing `randf_range` variance lines, so the tier multiplies the base export values and variance applies on top. Default `1.0` preserves existing behavior for all waves that don't set the tier.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — `speed_tier` defaults to 1.0 intentionally. WaveManager injection is deferred to Plan 04 as documented in the plan.

## Threat Flags

None — changes are pure AI state-machine logic with no new network endpoints, auth paths, file access, or schema changes.

## Self-Check: PASSED

- components/beeliner.gd: FOUND
- components/sniper.gd: FOUND
- components/flanker.gd: FOUND
- components/swarmer.gd: FOUND
- Commit a86a717 (Task 1): FOUND
- Commit 789edca (Task 2): FOUND
