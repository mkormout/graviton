---
phase: quick
plan: 260414-0ox
subsystem: camera
tags: [camera, ux, zoom, physics]
dependency_graph:
  requires: []
  provides: [cinematic-tracking-camera]
  affects: [world.gd, components/body_camera.gd]
tech_stack:
  added: []
  patterns: [velocity-based lerp zoom, onset/delay state machine, physics-synced camera]
key_files:
  created: []
  modified:
    - components/body_camera.gd
    - world.gd
decisions:
  - "_physics_process chosen over _process to sync camera with RigidBody2D velocity each physics step"
  - "ZOOM_DEFAULT raised from 0.20 to 0.25 for a closer resting feel"
  - "Two-timer state machine (time_fast / time_slow) chosen over single timer to handle onset and release independently"
  - "accel_bonus capped at 2.0 multiplier (3x total) to avoid over-aggressive zoom on brief bursts"
metrics:
  duration_minutes: 10
  completed_date: "2026-04-14"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
---

# Quick Task 260414-0ox: Improve Tracking Camera — Make it Primary Summary

**One-liner:** Cinematic velocity-based zoom with onset/release delays replacing instant per-frame zoom; BodyCamera made default camera via make_current() in _ready().

## What Was Built

### Task 1 — Make BodyCamera primary at game start (commit `6f78b6e`)

`world.gd`:
- `camera_follow` default changed from `false` to `true`
- `$ShipCamera.make_current()` added at the end of `_ready()` so the tracking camera is active from frame 1 without any KEY_C press

The KEY_C toggle was left untouched — it now cycles: ship-follow (default) → overview → ship-follow.

### Task 2 — Cinematic velocity-based zoom rewrite (commit `3251914`)

`components/body_camera.gd` fully replaced:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| ZOOM_DEFAULT | 0.25 | Resting zoom (closer than old 0.20) |
| ZOOM_MIN | 0.10 | Max zoom-out at high sustained speed |
| SPEED_THRESHOLD | 600 px/s | Below this, zoom-out is suppressed |
| ZOOM_OUT_ONSET | 0.6 s | Ship must exceed threshold this long before zoom-out starts |
| ZOOM_IN_DELAY | 0.8 s | After slowing, camera holds wide this long before zooming back in |
| ZOOM_OUT_RATE | 1.5/s | Lerp rate zooming out (+ accel_bonus) |
| ZOOM_IN_RATE | 0.8/s | Lerp rate zooming in (slower = more cinematic) |
| SPEED_MAX | 4000 px/s | Reference speed for full zoom-out |

Acceleration bonus: `accel_bonus = clamp(accel / 2000, 0, 2)` scales ZOOM_OUT_RATE up to 3x, making hard acceleration feel responsive without affecting slow drift.

Removed: the dead `zoom_levels: Array[ZoomLevel]` export.

Switched from `_process` to `_physics_process` so speed readings align with the physics tick that updates `linear_velocity`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. The `if not body: return` guard (T-0ox-02 mitigation) is present as specified.

## Self-Check

**Commits:**
- `6f78b6e` — Task 1 world.gd changes
- `3251914` — Task 2 body_camera.gd rewrite

**Files modified:**
- `/components/body_camera.gd` — exists, rewritten
- `/world.gd` — exists, two changes applied

## Self-Check: PASSED
