---
plan: 05-02
phase: 05-beeliner-wavemanager
status: complete
wave: 2
completed: 2026-04-12
commits:
  - 08ffc4d
  - e2c2a8c
  - a87c4e1
  - 23a4722
  - 473f7a3
  - 75b388e
  - a9b6ddb
---

## Summary

WaveManager created and wired into world.tscn/world.gd. Full Beeliner wave pipeline verified by human in Godot 4.6.2.

## What Was Built

- `components/wave-manager.gd` — WaveManager extending Node. Spawns enemies outside viewport (radius ~6510+ units from player), tracks wave completion via `tree_exiting` signal (not `get_children`), guards against overlapping waves and negative counters.
- `world.tscn` — WaveManager node added as direct child of root.
- `world.gd` — Player added to "player" group, 6 Fibonacci-scaled waves configured, KEY_F triggers waves.
- `components/enemy-bullet.gd` — EnemyBullet base class with `_draw()` debug visualization (orange circle + crosshair). Overrides `collision()` to skip EnemyShip instances (no friendly fire).

## Key Decisions Made During Execution

- Enemy bullets use collision_layer=256 (layer 9) / collision_mask=1 (Ship) to reach player without triggering enemy HitBoxes
- `EnemyBullet.collision()` returns early for EnemyShip bodies — bullets pass through allies
- Bullets spawn at 350 units from center (past HitBox radius of 300) to prevent self-collision on spawn
- `global_position` set after `add_child` (Godot requirement for RigidBody2D)
- Beeliner tuned: detection_radius=10000, max_speed=2000, thrust=1500, fight_range=8000, bullet_speed=4400, ±20% per-spawn variability on thrust/max_speed

## Deviations from Plan

- `waves: Array[Dictionary]` changed to `waves: Array` — GDScript typed Array[Dictionary] rejects plain Array assignment from external code
- Debug prints added to `_fire()` and `_enter_state` during investigation (left in for now)
- Beeliner HitBox radius increased to 300 to match debug draw circle

## Self-Check

- [x] wave-manager.gd exists with `class_name WaveManager` and `extends Node`
- [x] `tree_exiting` signal used for wave completion (no `get_children`)
- [x] KEY_F triggers `$WaveManager.trigger_wave()` in world.gd
- [x] WaveManager node in world.tscn
- [x] Human verified: waves spawn, enemies seek/fight/fire/die/drop loot, wave completion detected
- [x] No friendly fire between enemies

## Self-Check: PASSED
