---
phase: 18-weapons-improvements
plan: "02"
subsystem: weapons
tags: [laser, bounce, CharacterBody2D, physics, projectile]
dependency_graph:
  requires: []
  provides: [LaserBullet-CharacterBody2D]
  affects: [prefabs/laser/laser-bullet.tscn, prefabs/laser/laser-bullet.gd]
tech_stack:
  added: [CharacterBody2D-based projectile pattern]
  patterns: [move_and_collide bounce, call_deferred child spawning, null-safe optional FX]
key_files:
  created:
    - prefabs/laser/laser-bullet.gd
  modified:
    - prefabs/laser/laser-bullet.tscn
decisions:
  - "Use CharacterBody2D + move_and_collide() instead of RigidBody2D + body_entered signal — only CharacterBody2D provides collision normal via KinematicCollision2D.get_normal() needed for velocity.bounce()"
  - "Spawn bounce children via LaserBullet.new() (script-only node) not scene instantiation — avoids needing a .tscn reference within the bullet itself"
  - "collision_layer/mask set in _ready() not in .tscn — prevents stale values on dynamically spawned child bullets"
  - "bounce_flash_scene exported but null-safe — plan 18-07 will wire the actual FX scene; no crash if unset"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-18T23:12:07Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 18 Plan 02: Laser Bullet Bounce — CharacterBody2D Implementation Summary

**One-liner:** LaserBullet rewritten as CharacterBody2D using move_and_collide + velocity.bounce(normal) to reflect off surfaces up to 3 times, spawning 2 spread children per bounce with null-safe green flash FX.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Write laser-bullet.gd as CharacterBody2D with bounce logic | 9365475 | prefabs/laser/laser-bullet.gd (created) |
| 2 | Update laser-bullet.tscn root node to CharacterBody2D | 911bf1a | prefabs/laser/laser-bullet.tscn (modified) |

## What Was Built

**prefabs/laser/laser-bullet.gd** — New standalone GDScript (no Body/RigidBody2D inheritance):
- `extends CharacterBody2D` with `class_name LaserBullet`
- `_physics_process()` calls `move_and_collide(velocity * delta)` each frame
- `_on_impact()` applies full `Damage` to any `Body` collider, spawns green flash, then either queue_frees (bounce limit reached) or reflects and spawns 2 child bullets
- `_spawn_child()` creates `LaserBullet.new()` instances with `bounce_count + 1` and `call_deferred("add_child")` via `spawn_parent`
- `_spawn_flash()` instantiates `bounce_flash_scene` at contact point; null-safe if scene not assigned
- Threat mitigations: bounce guard (`bounce_count >= max_bounces`), life timer (2s via `create_timer`), explicit collision layer/mask in `_ready()`, `spawn_parent` null guard with `push_warning`

**prefabs/laser/laser-bullet.tscn** — Scene root updated:
- Root node changed from `RigidBody2D` to `CharacterBody2D`
- Script ext_resource updated from `components/bullet.gd` to `prefabs/laser/laser-bullet.gd`
- Removed RigidBody2D-only properties: `contact_monitor`, `max_contacts_reported`, `collision_layer`, `collision_mask`, `death`
- Retained: `CollisionShape2D` (required for `move_and_collide` detection), `Sprite2D`, `PointLight2D`
- Retained: `attack` sub-resource (Damage with energy=100.0)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `bounce_flash_scene` is exported but not assigned in `.tscn`. The green flash will not render until plan 18-07 assigns a `CPUParticles2D` scene. The bullet logic is complete and null-safe; no crash occurs with an unset flash scene.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. All surface is local physics simulation within the Godot scene tree.

## Self-Check: PASSED

- `prefabs/laser/laser-bullet.gd` — FOUND (created, 71 lines)
- `prefabs/laser/laser-bullet.tscn` — FOUND (modified, root = CharacterBody2D)
- Commit `9365475` — FOUND (Task 1)
- Commit `911bf1a` — FOUND (Task 2)
- `grep "class_name LaserBullet"` — 1 match
- `grep "extends CharacterBody2D"` — 1 match
- `grep "move_and_collide"` — 1 match
- `grep "velocity.bounce"` — 1 match
- `grep "bounce_count"` — 4 lines (declaration, guard, spawn arg, increment)
- `grep "call_deferred"` — 2 lines (child spawn, flash spawn)
- `grep "extends Body\|extends RigidBody2D"` — 0 results
- `grep "type=\"CharacterBody2D\""` in .tscn — 1 match on root node
- `grep "type=\"RigidBody2D\""` in .tscn — 0 results
