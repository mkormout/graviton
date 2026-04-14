---
plan: 06-02
phase: 6
subsystem: enemy-ai
tags: [enemy, sniper, scene, wave-manager, playtest, approved]
dependency_graph:
  requires: [components/sniper.gd, prefabs/enemies/sniper/sniper-bullet.tscn, prefabs/enemies/base-enemy-ship.tscn, prefabs/enemies/beeliner/beeliner.tscn]
  provides: [prefabs/enemies/sniper/sniper.tscn]
  affects: [world.gd]
tech_stack:
  added: []
  patterns: [inherited-scene, wave-manager-integration]
key_files:
  created:
    - prefabs/enemies/sniper/sniper.tscn
  modified:
    - world.gd
decisions:
  - "sniper.tscn uses uid://sniper_scene_001 — unique UID following beeliner_scene_001 pattern"
  - "FireTimer wait_time=3.0 (2x Beeliner's 1.5s) — slower fire cycle befitting standoff sniper"
  - "Sniper wave inserted as index 1 in WaveManager for immediate playtest access after first Beeliner wave"
metrics:
  duration: "~15 minutes"
  completed_date: "2026-04-12"
  tasks_completed: 2
  files_created: 1
  files_modified: 1
  tasks_pending: 1
---

# Phase 6 Plan 02: Sniper Scene + WaveManager Integration + Playtest Summary

## One-liner

Sniper inherited scene (base-enemy-ship.tscn + sniper.gd) with tuned exports (max_health=50, max_speed=1500, fight_range=900), AimTimer telegraph, loot droppers, and WaveManager integration as wave 2.

## What Was Built

### Task 1 — Sniper scene (prefabs/enemies/sniper/sniper.tscn) — commit 279e1e8

Created the Sniper inherited scene following the beeliner.tscn pattern exactly. Key elements:

- **Scene inheritance**: extends `base-enemy-ship.tscn`, script overridden to `sniper.gd`
- **Tuned exports**: max_health=50 (tougher than Beeliner's 30), max_speed=1500, thrust=1200, fight_range=900, comfort_range=600, flee_range=300, safe_range=700, aim_up_time=1.0, bullet_speed=1500
- **FireTimer**: wait_time=3.0, one_shot=false — 2x slower fire cycle than Beeliner's 1.5s
- **AimTimer**: wait_time=1.0, one_shot=true — telegraph pause node (new vs Beeliner)
- **CoinDropper**: ItemDropper with coin-copper (chance=1.0), drop_count=2
- **AmmoDropper**: ItemDropper with minigun-ammo (chance=0.5) + no-drop (chance=0.5), drop_count=1
- **No picker Area2D** — ENM-15 compliance, same as Beeliner

### Task 2 — WaveManager integration (world.gd) — commit 4960c1e

Modified `world.gd` to add Sniper to the wave composition:

- Added `var sniper_model = preload("res://prefabs/enemies/sniper/sniper.tscn")` after `beeliner_model`
- Inserted `{ "enemy_scene": sniper_model, "count": 2 }` as second wave (index 1)
- Wave order: Beeliner×3 → Sniper×2 → Beeliner×5
- Existing waves and KEY_F trigger unchanged

## Commits

| Task | Description | Hash |
|------|-------------|------|
| T01 | Add sniper.tscn — inherited scene with 3-band AI exports and fire/aim timers | 279e1e8 |
| T02 | Wire Sniper into WaveManager — preload + wave 2 entry | 4960c1e |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `prefabs/enemies/sniper/sniper.tscn` Sprite2D child has no texture assigned — EnemyBullet._draw() debug visual (orange circle + crosshair) will be visible until art is provided. Same condition as Beeliner.

## Pending

### Task 3 — Playtest Sniper behavior (checkpoint:human-verify)

**Status:** PENDING — awaiting human playtest

**What to verify:**
1. Open project in Godot editor — verify no parse errors in sniper.gd, sniper.tscn, sniper-bullet.tscn
2. Run game (F5), press F to trigger wave 1 (Beeliners), then F again for wave 2 (Snipers — 2 should spawn)
3. Observe Sniper behavior:
   - Snipers maintain standoff distance (do NOT charge to melee like Beeliners)
   - STATE label shows SEEKING -> FIGHTING transition
   - After entering FIGHTING, ~1 second aim-up pause before firing
   - Sniper bullets are visibly SLOWER than Beeliner bullets
   - Sniper bullets deal noticeably MORE damage per hit
4. Fly toward a Sniper aggressively — Sniper should transition to FLEEING, move away, return to SEEKING when you back off
5. Kill the Snipers — loot drops appear, wave completes

**Resume signal:** Type "approved" if all behaviors check out, or describe issues

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| prefabs/enemies/sniper/sniper.tscn exists | FOUND |
| world.gd contains sniper_model preload | FOUND |
| world.gd waves array has sniper wave | FOUND |
| commit 279e1e8 exists | FOUND |
| commit 4960c1e exists | FOUND |
