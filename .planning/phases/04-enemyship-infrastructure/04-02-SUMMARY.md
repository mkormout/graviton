---
phase: 04-enemyship-infrastructure
plan: 02
subsystem: enemy-ai
tags: [enemy-ship, scene, gdscript, test-enemy, world, hitbox, verification]
dependency_graph:
  requires: [04-01]
  provides: [base-enemy-ship.tscn skeleton, test enemy in world, HitBox bullet detection]
  affects: [prefabs/enemies/base-enemy-ship.tscn, world.gd, components/enemy-ship.gd]
tech_stack:
  added: []
  patterns: [godot-tscn-scene, spawn-parent-propagation, detection-area, hitbox-area2d, debug-draw]
key_files:
  created:
    - prefabs/enemies/base-enemy-ship.tscn
  modified:
    - world.gd
    - components/enemy-ship.gd
decisions:
  - "HitBox Area2D (collision_mask=4) used for bullet detection — avoids modifying all bullet scenes"
  - "ItemDropper node uses Node2D type (matches ItemDropper class which extends Node2D)"
  - "spawn_test_enemy() placed after spawn_asteroids() in _ready() per plan spec"
metrics:
  duration: "~45 minutes (includes verification fixes)"
  completed_date: "2026-04-11"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 3
status: complete
---

# Phase 04 Plan 02: EnemyShip Scene + World Test — Summary

Base enemy ship skeleton scene with correct node hierarchy, test enemy spawned in world.gd, debug visuals, bullet hitbox, and human verification approved.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create base-enemy-ship.tscn skeleton scene | 1437916 | prefabs/enemies/base-enemy-ship.tscn |
| 2 | Place test enemy in world.gd for Phase 4 verification | 689da77 | world.gd |
| 3 | Verify EnemyShip detection and state transition | — | approved by user |

## What Was Built

### Task 1 — base-enemy-ship.tscn skeleton scene

Created `prefabs/enemies/base-enemy-ship.tscn` with node hierarchy:

```
EnemyShip (RigidBody2D) — root
├── CollisionShape2D  (CircleShape2D radius=30 placeholder)
├── Sprite2D           (no texture — concrete types assign)
├── DetectionArea (Area2D, mask=1 Ship layer, radius=800)
│   └── DetectionShape
├── HitBox (Area2D, mask=4 Bullets layer, radius=30)
│   └── HitBoxShape
├── Barrel (Node2D, position=(40,0))
└── ItemDropper (Node2D with item-dropper.gd script)
```

No Picker, MountPoint, or Inventory nodes (ENM-15 compliant).

### Task 2 — world.gd test enemy placement

- `var enemy_model = preload("res://prefabs/enemies/base-enemy-ship.tscn")`
- `spawn_test_enemy()`: instantiates enemy at player+600px, calls `setup_spawn_parent`, prints confirmation
- Auto-spawns in `_ready()`; KEY_T to respawn
- `_input(_ev)` renamed to `_input(event)` to fix parse error from KEY_T handler

### Task 3 — Human Verification (approved)

- `[World] Test enemy spawned at ...]` logged on start
- `[EnemyShip] state: IDLING -> SEEKING` logged on player approach
- Debug visuals visible: inner ring (30px full-opacity), outer ring (300px half-opacity), yellow arrow, live state label
- Bullets now damage enemy via HitBox Area2D
- Player ship picker intact

## Issues Fixed During Verification

| Issue | Fix | Commit |
|-------|-----|--------|
| Parse error: `event` not in scope | Renamed `_input(_ev)` → `_input(event)` | e6c31fd |
| Enemy invisible (no sprite) | Added `_draw()` debug circle + arrow + state label | a6e872c, 68ca882 |
| Bullets pass through enemy | Added HitBox Area2D + `_on_hitbox_body_entered` | 857e30d |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| HitBox Area2D instead of modifying bullet scenes | Bullet collision_mask=8 (Asteroids only); adding Ship would cause friendly fire |
| Debug visuals in `_draw()` | Keeps scene minimal; auto-updates with node transform; removed on shipping |
| `queue_redraw()` in `_change_state` | State label redraws on every transition |

## Self-Check

- [x] `prefabs/enemies/base-enemy-ship.tscn` exists — FOUND
- [x] Scene contains HitBox Area2D with collision_mask=4 — FOUND
- [x] Scene contains DetectionArea, Barrel, ItemDropper — FOUND
- [x] Scene does NOT contain Picker, MountPoint, Inventory — CONFIRMED
- [x] `world.gd` contains `spawn_test_enemy` and enemy_model preload — FOUND
- [x] `components/enemy-ship.gd` contains `_on_hitbox_body_entered` — FOUND
- [x] `components/enemy-ship.gd` contains `_draw` with debug visuals — FOUND
- [x] Human verified in Godot — APPROVED

## Self-Check: PASSED
