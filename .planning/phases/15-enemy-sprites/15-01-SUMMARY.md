---
phase: 15-enemy-sprites
plan: "01"
subsystem: enemy-sprites
tags: [godot, sprites, enemy-ai, tween, pointlight, gdscript]
dependency_graph:
  requires: []
  provides:
    - "beeliner.gd: sprite_region, sprite_scale, gem_energy_min/max, gem_pulse_half_period @exports + _setup_sprite/_setup_gem_light/_start_pulse"
    - "sniper.gd: same 5 @exports + 3 helper functions"
    - "flanker.gd: same 5 @exports + 3 helper functions"
    - "swarmer.gd: same 5 @exports + 3 helper functions"
    - "suicider.gd: same 5 @exports + 3 helper functions"
  affects:
    - "Plan 02: scene wiring — GemLight + VisibleOnScreenNotifier2D nodes must be added to all 5 enemy .tscn files"
    - "Plan 04: playtest tuning — @export values are the starting point for editor adjustment"
tech_stack:
  added: []
  patterns:
    - "load() with null-check for SPR-03 atlas fallback (not preload)"
    - "create_tween().set_loops(0).set_trans(TRANS_SINE) for infinite gem pulse"
    - "VisibleOnScreenNotifier2D screen_entered/screen_exited for PointLight2D viewport culling"
    - "@export for all tunable sprite/gem values (per-enemy defaults set, editor-adjustable)"
key_files:
  created: []
  modified:
    - components/beeliner.gd
    - components/sniper.gd
    - components/flanker.gd
    - components/swarmer.gd
    - components/suicider.gd
decisions:
  - "Used load() not preload() for atlas — required for SPR-03 null-safe fallback path"
  - "sprite.rotation_degrees = -90.0 applied on Sprite2D child only — never on RigidBody2D root (preserves collision shapes)"
  - "All per-enemy @export defaults set per D-03/D-04/D-05 decisions and PATTERNS.md table; all marked ASSUMED pending editor visual verification in Plan 04"
  - "Identical _setup_sprite/_setup_gem_light/_start_pulse function bodies across all 5 scripts — no node path customization needed since all enemy scenes share the same node naming convention"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-17"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 5
---

# Phase 15 Plan 01: Enemy Script Sprite + Gem Light Setup Summary

**One-liner:** Added atlas sprite loading and TRANS_SINE pulsing PointLight2D gem setup to all five enemy GDScripts via five @export-tunable parameters and three private helper functions.

## What Was Built

Plan 01 is the pure script layer of Phase 15. All five enemy GDScripts (`beeliner.gd`, `sniper.gd`, `flanker.gd`, `swarmer.gd`, `suicider.gd`) received identical structural additions:

1. **Five new @export vars** — `sprite_region: Rect2`, `sprite_scale: Vector2`, `gem_energy_min: float`, `gem_energy_max: float`, `gem_pulse_half_period: float` — inserted after the existing @export block in each file, before the first `var _` or `const` declaration.

2. **Extended `_ready()`** — Two calls appended at the end of each file's existing `_ready()` body: `_setup_sprite()` then `_setup_gem_light()`. No existing lines reordered or removed.

3. **Three new private helper functions** appended at end of each file:
   - `_setup_sprite()` — loads `res://ships_assests.png` via `load()`, configures Sprite2D texture/region/rotation/scale, hides `$Shape` Polygon2D on success; returns early (SPR-03 fallback) if atlas is null
   - `_setup_gem_light()` — gets `$VisibleOnScreenNotifier2D` and `$GemLight`, starts light disabled, wires `screen_entered`/`screen_exited` signals to toggle `light.enabled`, calls `_start_pulse(light)`
   - `_start_pulse(light)` — creates infinite tween (`set_loops(0)`, `TRANS_SINE`) with two sequential `tween_property` calls animating `PointLight2D.energy` between `gem_energy_min` and `gem_energy_max`

## Per-Enemy Default Values

| Enemy | sprite_region | sprite_scale | gem_energy_min | gem_energy_max | gem_pulse_half_period |
|-------|---------------|--------------|----------------|----------------|-----------------------|
| Beeliner (ENM-07) | `Rect2(20, 10, 390, 700)` | `Vector2(1.76, 1.76)` | 0.5 | 1.8 | 0.6 |
| Sniper (ENM-08) | `Rect2(440, 10, 380, 780)` | `Vector2(1.81, 1.81)` | 0.2 | 2.5 | 1.5 |
| Flanker (ENM-09) | `Rect2(870, 30, 360, 720)` | `Vector2(1.43, 1.43)` | 0.4 | 1.6 | 0.8 |
| Swarmer (ENM-10) | `Rect2(1295, 50, 360, 650)` | `Vector2(0.96, 0.96)` | 0.3 | 2.0 | 0.25 |
| Suicider (ENM-11) | `Rect2(1720, 80, 340, 640)` | `Vector2(1.01, 1.01)` | 0.6 | 3.0 | 0.15 |

All `sprite_region` and `sprite_scale` values are **ASSUMED** — require visual verification in the Godot editor sprite region tool (Plan 04 checkpoint). All values are `@export`-tunable for post-playtest adjustment without code changes.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: beeliner + suicider | `03d5291` | components/beeliner.gd, components/suicider.gd |
| Task 2: sniper + flanker + swarmer | `99b43e5` | components/sniper.gd, components/flanker.gd, components/swarmer.gd |

## Deviations from Plan

None — plan executed exactly as written. All insertions were pure additions; `git diff` for all five files shows 0 deletions.

## Runtime Behavior Note

Scripts reference `$GemLight` (PointLight2D) and `$VisibleOnScreenNotifier2D` nodes that do not yet exist in the enemy `.tscn` files. Calls to `_setup_gem_light()` will produce runtime errors until Plan 02 adds these nodes to the scenes. This is expected and documented in the plan — verification boundary for Plan 01 is script-level syntax only, not runtime behavior.

## Known Stubs

None — no hardcoded empty values or placeholder text flowing to UI rendering. The @export default values are assumed atlas regions that will be tuned in Plan 04, but this is a documented design decision (D-09), not an unintentional stub.

## Threat Flags

None — this plan adds no network endpoints, auth paths, file access patterns beyond the single read-only `load("res://ships_assests.png")`, or schema changes at trust boundaries.

## Self-Check: PASSED

Files exist:
- `components/beeliner.gd` — FOUND (modified)
- `components/sniper.gd` — FOUND (modified)
- `components/flanker.gd` — FOUND (modified)
- `components/swarmer.gd` — FOUND (modified)
- `components/suicider.gd` — FOUND (modified)

Commits exist:
- `03d5291` — FOUND (feat(15-01): add sprite + gem light setup to beeliner and suicider)
- `99b43e5` — FOUND (feat(15-01): add sprite + gem light setup to sniper, flanker, swarmer)
