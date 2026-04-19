---
phase: 18-weapons-improvements
plan: "08"
subsystem: bullet-fx
tags: [visual-effects, bullets, particles, line2d, trails, impact-fx]
dependency_graph:
  requires: [18-02, 18-03, 18-04, 18-05, 18-06]
  provides: [bullet-trail-fx, bullet-impact-fx, laser-bounce-flash-fx]
  affects: [prefabs/minigun, prefabs/gausscannon, prefabs/rpg, prefabs/laser, prefabs/ui]
tech_stack:
  added: [CPUParticles2D one-shot auto-free pattern, Line2D local-space static trail]
  patterns: [spawn_parent.call_deferred add_child for deferred FX spawning, finished.connect(queue_free) for auto-free particles]
key_files:
  created:
    - prefabs/ui/bullet-impact.gd
    - prefabs/ui/bullet-impact.tscn
    - prefabs/laser/laser-bounce-flash.gd
    - prefabs/laser/laser-bounce-flash.tscn
    - prefabs/minigun/minigun-bullet.gd
    - prefabs/gausscannon/gausscannon-bullet.gd
  modified:
    - prefabs/rpg/rpg-bullet.gd
    - prefabs/minigun/minigun-bullet.tscn
    - prefabs/gausscannon/gausscannon-bullet.tscn
    - prefabs/rpg/rpg-bullet.tscn
    - prefabs/laser/laser-bullet.tscn
decisions:
  - "Line2D trail uses fixed local-space points (no per-frame update) — bullets move fast enough that static trailing points appear as motion blur streaks"
  - "Impact FX use finished.connect(queue_free) with one_shot=true to auto-free after emission — prevents scene tree accumulation"
  - "FX spawned to spawn_parent via call_deferred to ensure persistence after bullet queue_free"
  - "_spawn_impact guards on both impact_scene and spawn_parent before instantiating — no crash if export not assigned"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-18"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 5
---

# Phase 18 Plan 08: Bullet Trail and Impact FX Summary

One-liner: CPUParticles2D impact sparks with auto-free and static local-space Line2D motion-blur trails added to all four bullet types, with laser-bounce-flash.tscn wired to laser-bullet.tscn bounce_flash_scene export.

## What Was Built

Added visual feedback for bullet travel and hits across all weapon types:

- **bullet-impact.tscn** — Reusable one-shot CPUParticles2D (10 particles, 0.25s, warm orange) with auto-free via `finished.connect(queue_free)`.
- **laser-bounce-flash.tscn** — One-shot CPUParticles2D (12 particles, 0.2s, green) for laser bounce contact points, also auto-free.
- **MinigunBullet** (`minigun-bullet.gd`) — New script extending Bullet; overrides `collision()` to spawn impact FX before `super.collision()`.
- **GausscannonBullet** (`gausscannon-bullet.gd`) — Same pattern as MinigunBullet.
- **RpgBullet** (`rpg-bullet.gd`) — Extended existing homing script with `impact_scene` export and same collision FX pattern.
- **All four bullet .tscn files** — Updated with Line2D Trail child nodes (local-space fixed points for motion-blur effect) and export bindings for impact_scene / bounce_flash_scene.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create impact FX scenes and update bullet scripts | 7bed802 | bullet-impact.gd/tscn, laser-bounce-flash.gd/tscn, minigun-bullet.gd, gausscannon-bullet.gd, rpg-bullet.gd |
| 2 | Add Line2D trails to bullet scenes and assign bindings | 63ab265 | minigun-bullet.tscn, gausscannon-bullet.tscn, rpg-bullet.tscn, laser-bullet.tscn |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Mitigations Applied

| Threat | Mitigation |
|--------|-----------|
| T-18-08-01: FX node accumulation | `finished.connect(queue_free)` in both FX scripts; one_shot ensures rapid cleanup within 0.2-0.25s |
| T-18-08-02: spawn_parent null crash | `if not impact_scene or not spawn_parent: return` guard in every `_spawn_impact()` |
| T-18-08-03: super.collision after die() | Accepted — Body.die() starts a timer, not immediate queue_free; super.collision() is safe |

## Known Stubs

None — all export bindings are wired in .tscn files; FX scenes are complete with real particle parameters.

## Self-Check: PASSED

Files exist:
- prefabs/ui/bullet-impact.gd: FOUND
- prefabs/ui/bullet-impact.tscn: FOUND
- prefabs/laser/laser-bounce-flash.gd: FOUND
- prefabs/laser/laser-bounce-flash.tscn: FOUND
- prefabs/minigun/minigun-bullet.gd: FOUND
- prefabs/gausscannon/gausscannon-bullet.gd: FOUND

Commits exist:
- 7bed802: FOUND (Task 1)
- 63ab265: FOUND (Task 2)
