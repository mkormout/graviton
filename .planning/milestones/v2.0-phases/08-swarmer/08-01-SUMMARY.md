---
phase: 08-swarmer
plan: "01"
subsystem: enemy-ai
tags: [enemy, swarmer, ai, cohesion, gdscript]
dependency_graph:
  requires: [components/enemy-ship.gd, components/enemy-bullet.gd, prefabs/minigun/minigun-bullet-explosion.tscn]
  provides: [components/swarmer.gd, prefabs/enemies/swarmer/swarmer-bullet.tscn]
  affects: [prefabs/enemies/swarmer/swarmer.tscn (Plan 02)]
tech_stack:
  added: []
  patterns: [EnemyShip state machine, Area2D cohesion tracking, apply_central_force with scale, linear falloff separation]
key_files:
  created:
    - components/swarmer.gd
    - prefabs/enemies/swarmer/swarmer-bullet.tscn
  modified: []
decisions:
  - "Used inline apply_central_force with force_scale parameter instead of steer_toward() — required for cohesion thrust reduction (D-07, D-08)"
  - "Linear falloff for separation force (not inverse-square) — avoids jitter at close range"
  - "collision_layer=256 (Layer 9) for bullet — matches all enemy bullets, overrides CONTEXT.md documentation error about Layer 3"
metrics:
  duration: 84 seconds
  completed: 2026-04-13
  tasks_completed: 2
  files_created: 2
---

# Phase 8 Plan 01: Swarmer Script and Bullet Scene Summary

**One-liner:** Swarmer GDScript with IDLING/SEEKING/FIGHTING state machine, Area2D cohesion tracking, per-instance angle-offset steering, and a matching weak bullet scene (energy=3.0, Layer 9).

## What Was Built

**Task 1: components/swarmer.gd**

The Swarmer concrete enemy class extending EnemyShip. Key mechanics:

- **State machine**: IDLING → SEEKING → FIGHTING → SEEKING/IDLING (no FLEEING/LURKING/EVADING per D-13)
- **Angle offset**: `_angle_offset = deg_to_rad(randf_range(-40.0, 40.0))` baked in `_ready()` and applied during SEEKING via `raw_dir.rotated(_angle_offset)` — spreads the cluster across multiple approach vectors
- **Cohesion thrust scale**: `force_scale = cohesion_thrust_scale (0.3)` when `_nearby_swarmers.size() > 0`, applied in both SEEKING and FIGHTING states via inline `apply_central_force()` (not `steer_toward()`)
- **CohesionArea**: Area2D with `collision_layer=0, collision_mask=1`; `body_entered/body_exited` signals maintain `_nearby_swarmers: Array[EnemyShip]`; filtered by `body is Swarmer and body != self`
- **Separation**: `_apply_separation()` called in `_physics_process` after `super(delta)`; uses linear falloff `separation_force * (1.0 - clampf(dist / cohesion_radius, 0.0, 1.0))`; `is_instance_valid()` guard per-swarmer
- **Fire loop**: Timer-based; immediate `_fire()` on FIGHTING entry, then `_fire_timer.start()`; `_on_fire_timer_timeout` guards `dying or current_state != FIGHTING`
- **Bullet spawn**: `spawn_parent.add_child(bullet)` at `_barrel.global_position` (Flanker pattern)
- **Hysteresis**: FIGHTING → SEEKING at `dist > fight_range * 1.2` (prevents oscillation)
- **die()**: `_fire_timer.stop()` + `_ammo_dropper.drop()` + `super(delay)` — identical to Beeliner/Flanker

**Task 2: prefabs/enemies/swarmer/swarmer-bullet.tscn**

Structural copy of flanker-bullet.tscn with reduced damage values:
- Root: `SwarmerBullet` (RigidBody2D)
- `collision_layer=256` (Layer 9 — enemy bullet layer), `collision_mask=1` (Ship)
- `energy=3.0` (lower than Beeliner/Flanker 5.0), `kinetic=0.0`
- `mass=20.0` (lighter than Flanker 30.0, Beeliner 50.0)
- `RectangleShape2D size=Vector2(8, 56)` (smaller than other bullets)
- Script: `enemy-bullet.gd` (EnemyBullet — includes EnemyShip self-hit guard)
- Death: `minigun-bullet-explosion.tscn`
- Sprite2D: blank (art deferred per scope)

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria verified before each commit.

## Threat Mitigations Applied

All 5 threats from the plan's threat model are mitigated:

| Threat | Mitigation |
|--------|-----------|
| T-08-01 DoS (runaway bullets) | `if dying: return` in `_fire()` and timer timeout guard |
| T-08-02 Stale reference crash | `is_instance_valid(swarmer)` before each `global_position` access |
| T-08-03 Player treated as groupmate | `body is Swarmer and body != self` filter in `_on_cohesion_area_body_entered` |
| T-08-04 Separation on dying Swarmer | `if dying: return` after `super(delta)` in `_physics_process` |
| T-08-05 Wrong collision layer | `collision_layer=256` (Layer 9) confirmed correct; Layer 3 in CONTEXT.md was documentation error |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 5612ede | feat(08-01): create Swarmer AI script |
| 2 | 70472fa | feat(08-01): create swarmer-bullet projectile scene |

## Self-Check: PASSED
