---
phase: 04-enemyship-infrastructure
plan: 01
subsystem: enemy-ai
tags: [enemy-ship, state-machine, gdscript, ai-foundation]
dependency_graph:
  requires: []
  provides: [EnemyShip base class, picker null guard]
  affects: [components/ship.gd, components/enemy-ship.gd]
tech_stack:
  added: []
  patterns: [state-machine, dying-guard, steering-via-force, detection-area]
key_files:
  created: []
  modified:
    - components/ship.gd
    - components/enemy-ship.gd
decisions:
  - "No fire loop in base class — concrete enemy types implement fire independently (D-06)"
  - "Detection area uses collision_mask layer 1 (Ship) only — cannot detect bullets/asteroids"
  - "State debug print() retained in _change_state per D-18 for Phase 4 development"
metrics:
  duration: "~15 minutes"
  completed_date: "2026-04-11"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 04 Plan 01: EnemyShip Infrastructure — Base Class Summary

EnemyShip base class with 8-state machine, dying guard, steering helpers, and detection wiring; plus picker null guard in Ship._ready() to prevent crash on EnemyShip instantiation.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add picker null guard in Ship._ready() | b53c8f3 | components/ship.gd |
| 2 | Build out EnemyShip base class script | 048b71d | components/enemy-ship.gd |

## What Was Built

### Task 1 — Ship._ready() picker null guard

Added `if picker:` guard around `picker.connect("body_entered", picker_body_entered)` in `components/ship.gd`. EnemyShip scenes have no picker Area2D node (per D-02), so `Ship._ready()` would crash on null dereference without the guard. PlayerShip scenes (which do have picker assigned) continue to work unchanged.

### Task 2 — EnemyShip base class

Replaced the 2-line stub in `components/enemy-ship.gd` with the full base class:

- **8-state enum**: IDLING, SEEKING, LURKING, FIGHTING, FLEEING, PATROLLING, EVADING, ESCORTING
- **State machine infrastructure**: `_tick_state()`, `_enter_state()`, `_exit_state()` virtual methods; `_change_state()` helper that calls exit/update/enter in order with debug print
- **Dying guard**: `_physics_process()` and `_on_detection_area_body_entered()` both return early when `dying == true` — prevents AI ticking and state transitions during the death delay window
- **Steering**: `steer_toward(target_position)` applies `apply_central_force(direction * thrust)`; `_integrate_forces()` clamps `linear_velocity` with `limit_length(max_speed)`
- **Detection wiring**: `DetectionArea` collision_mask set to layer 1 (Ship only); `body_entered` signal drives IDLING→SEEKING transition with `body is PlayerShip` type check
- **Exports**: `max_speed: float = 500.0`, `thrust: float = 200.0`, `detection_radius: float = 800.0`
- **Fire pattern convention**: Block comment documents how concrete types implement fire independently (no base class fire loop per D-06)

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| No fire Timer or fire() in base class | Per D-06: concrete enemy types implement fire logic independently; reduces coupling and lets each type balance independently |
| Detection mask layer 1 (Ship) only | Enemies should only react to ships entering range, not bullets, asteroids, or items |
| `if dying: return` in detection handler | Signals can fire after `dying = true` but before `queue_free()` — guard prevents invalid state transitions in the death delay window |
| `limit_length` in `_integrate_forces` not `_physics_process` | Velocity clamping in `_integrate_forces` is the correct Godot 4 pattern for RigidBody2D velocity limits |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Mitigations Applied

| Threat | Mitigation |
|--------|-----------|
| T-04-01: State change on invalid body or during death | `if dying: return` + `body is PlayerShip` type check in `_on_detection_area_body_entered` |
| T-04-02: Unbounded velocity from repeated force | `state.linear_velocity.limit_length(max_speed)` in `_integrate_forces` |

## Known Stubs

None — no placeholder data or hardcoded empty values introduced.

## Self-Check

- [x] `components/ship.gd` contains `if picker:` guard — FOUND
- [x] `components/enemy-ship.gd` contains `enum State` with 8 values — FOUND
- [x] `components/enemy-ship.gd` contains 2 occurrences of `if dying:` — FOUND (lines 33, 63)
- [x] `components/enemy-ship.gd` contains `apply_central_force` in `steer_toward` — FOUND
- [x] `components/enemy-ship.gd` contains `limit_length(max_speed)` in `_integrate_forces` — FOUND
- [x] `components/enemy-ship.gd` contains 0 occurrences of `Timer|bullet_scene` — CONFIRMED
- [x] Commit b53c8f3 exists — FOUND
- [x] Commit 048b71d exists — FOUND

## Self-Check: PASSED
