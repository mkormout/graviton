---
phase: 18-weapons-improvements
plan: "01"
subsystem: weapons/physics/camera
tags: [recoil, physics, camera-shake, bug-fix]
dependency_graph:
  requires: []
  provides: [recoil-fix, camera-shake-api]
  affects: [components/mountable-body.gd, components/body_camera.gd]
tech_stack:
  added: []
  patterns: [apply_central_impulse, tween-kill-guard, Camera2D-offset-shake]
key_files:
  created: []
  modified:
    - components/mountable-body.gd
    - components/body_camera.gd
decisions:
  - "Use apply_central_impulse(vector) instead of apply_impulse(vector, place) — eliminates off-center torque with zero-argument simplification"
  - "BodyCamera.shake() uses tween kill guard (per T-18-01-01 DoS threat) — prevents tween accumulation from rapid firing"
  - "shake() wiring to weapon fired_heavy signals deferred to plan 18-10 (world.gd)"
metrics:
  duration: "1 minute"
  completed: "2026-04-18"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 18 Plan 01: Recoil Bug Fix + Camera Shake Foundation Summary

**One-liner:** Fixed off-center recoil torque via apply_central_impulse and added tween-based shake() API to BodyCamera for heavy weapon use.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix recoil bug in mountable-body.gd | e70f4cb | components/mountable-body.gd |
| 2 | Add shake() method to BodyCamera | 46bde55 | components/body_camera.gd |

## What Was Built

### Task 1 — Recoil Bug Fix

In `components/mountable-body.gd` the RECOIL action handler was calling `apply_impulse(vector, place)` where `place = sender.global_position / 100`. Godot's `apply_impulse` expects a LOCAL offset from the body's center — passing the weapon's world position divided by 100 produced a near-zero but non-zero offset, causing unintended torque and ship spin every time a weapon fired.

Fix: replaced both lines (`var place = ...` and `apply_impulse(vector, place)`) with a single `apply_central_impulse(vector)` call. The recoil direction was already correct (D-02); only the application point was wrong.

### Task 2 — BodyCamera shake() Method

Added to `components/body_camera.gd`:
- `var _shake_tween: Tween = null` — instance variable to track the active shake tween
- `func shake(magnitude: float = 8.0, duration: float = 0.3) -> void` — tweens the Camera2D `offset` property through 6 random positions over `duration` seconds, then snaps back to `Vector2.ZERO`
- Tween kill guard (`_shake_tween.kill()` if running) prevents tween accumulation under rapid fire (addresses threat T-18-01-01)

The method is self-contained. Signal wiring to heavy weapons (Gausscannon, RPG, GravityGun) will be added in plan 18-10 via `world.gd`.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Model Compliance

| Threat ID | Disposition | Status |
|-----------|-------------|--------|
| T-18-01-01 | mitigate | Tween kill guard implemented in shake() — prevents DoS from tween accumulation |
| T-18-01-02 | accept | No action needed — meta float is internal from trusted weapon scripts |
| T-18-01-03 | accept | No action needed — impulse magnitude bounded by developer-set export values |

## Self-Check: PASSED

- components/mountable-body.gd: FOUND
- components/body_camera.gd: FOUND
- 18-01-SUMMARY.md: FOUND
- Commit e70f4cb: FOUND
- Commit 46bde55: FOUND
