---
phase: 15-enemy-sprites
plan: "02"
subsystem: enemy-scenes
tags: [godot, scene, pointlight, visibility, gradient, gem-light]
one_liner: "GemLight PointLight2D + VisibleOnScreenNotifier2D + GradientTexture2D added to all 5 enemy ship scenes"

dependency_graph:
  requires: [15-01]
  provides: [scene-gem-nodes-all-enemies]
  affects: [prefabs/enemies/beeliner/beeliner.tscn, prefabs/enemies/sniper/sniper.tscn, prefabs/enemies/flanker/flanker.tscn, prefabs/enemies/swarmer/swarmer.tscn, prefabs/enemies/suicider/suicider.tscn]

tech_stack:
  added: []
  patterns: [GradientTexture2D radial falloff, PointLight2D gem glow, VisibleOnScreenNotifier2D viewport culling]

key_files:
  created: []
  modified:
    - prefabs/enemies/beeliner/beeliner.tscn
    - prefabs/enemies/sniper/sniper.tscn
    - prefabs/enemies/flanker/flanker.tscn
    - prefabs/enemies/swarmer/swarmer.tscn
    - prefabs/enemies/suicider/suicider.tscn

decisions:
  - "shadow_enabled = false on all GemLights (RESEARCH pitfall 4: per-light shadow cost at wave-20 scale)"
  - "texture_scale varies by role tier: sniper/beeliner=8, flanker=7, swarmer=5, suicider=10 (dramatic gem)"
  - "GemLight position = Vector2(0,0) — Plan 04 will adjust after visual inspection"
  - "load_steps added to headers missing it (sniper, flanker, swarmer, suicider); Godot re-normalizes on next save"

metrics:
  duration_minutes: 15
  completed_date: "2026-04-17"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 5
---

# Phase 15 Plan 02: Enemy Scene GemLight Nodes Summary

GemLight PointLight2D + VisibleOnScreenNotifier2D + GradientTexture2D sub_resources added to all five enemy ship scenes, completing the scene-level complement to Plan 01's script setup.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | GemLight + VisibleOnScreenNotifier2D to beeliner + suicider | edc4933 | beeliner.tscn, suicider.tscn |
| 2 | GemLight + VisibleOnScreenNotifier2D to sniper + flanker + swarmer | 7bb79e1 | sniper.tscn, flanker.tscn, swarmer.tscn |

## Per-Enemy Scene Values (as committed)

| Enemy | GemLight color | energy | texture_scale | Notifier rect |
|-------|---------------|--------|---------------|---------------|
| Beeliner | Color(0.0, 0.9, 0.2, 1) — green | 0.5 | 8.0 | Rect2(-400, -400, 800, 800) |
| Sniper | Color(0.6, 0.0, 1.0, 1) — purple | 0.2 | 8.0 | Rect2(-400, -400, 800, 800) |
| Flanker | Color(1.0, 0.45, 0.0, 1) — orange | 0.4 | 7.0 | Rect2(-300, -300, 600, 600) |
| Swarmer | Color(1.0, 0.75, 0.0, 1) — amber | 0.3 | 5.0 | Rect2(-200, -200, 400, 400) |
| Suicider | Color(1.0, 0.05, 0.05, 1) — red | 0.6 | 10.0 | Rect2(-200, -200, 400, 400) |

Values match D-04 (gem colors) and D-08 (role tier sizes) from CONTEXT exactly.

## What Was Added to Each Scene

Each of the 5 enemy `.tscn` files received:
1. `[sub_resource type="Gradient" id="Gradient_gem_{enemy}"]` — white-to-transparent gradient
2. `[sub_resource type="GradientTexture2D" id="GradientTexture2D_gem_{enemy}"]` — 256x256, radial fill, HDR, references Gradient
3. `[node name="GemLight" type="PointLight2D" parent="."]` — per-enemy color, shadow_enabled=false, references GradientTexture2D
4. `[node name="VisibleOnScreenNotifier2D" type="VisibleOnScreenNotifier2D" parent="."]` — per-enemy rect

## Node Path Contract Satisfied

After Plan 01 (scripts) + Plan 02 (scenes), the following `$NodePath` references resolve at runtime:
- `$GemLight` → PointLight2D child of root RigidBody2D
- `$VisibleOnScreenNotifier2D` → VisibleOnScreenNotifier2D child of root RigidBody2D
- `$Sprite2D` → already existed (base-enemy-ship.tscn, untouched)
- `$Shape` → Polygon2D fallback (untouched, remains SPR-03 fallback)

No `region_rect` or texture overrides were added to Sprite2D nodes — runtime script handles them at `_ready()`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All values are real per-enemy data from D-04/D-08. Position = Vector2(0,0) is intentionally placeholder for Plan 04 editor tuning — this is documented in CONTEXT as expected.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary changes introduced.

## Self-Check

Files exist:
- prefabs/enemies/beeliner/beeliner.tscn — FOUND (contains GemLight, VisibleOnScreenNotifier2D, GradientTexture2D)
- prefabs/enemies/sniper/sniper.tscn — FOUND
- prefabs/enemies/flanker/flanker.tscn — FOUND
- prefabs/enemies/swarmer/swarmer.tscn — FOUND
- prefabs/enemies/suicider/suicider.tscn — FOUND

Commits exist:
- edc4933 — FOUND (Task 1: beeliner + suicider)
- 7bb79e1 — FOUND (Task 2: sniper + flanker + swarmer)

## Self-Check: PASSED
