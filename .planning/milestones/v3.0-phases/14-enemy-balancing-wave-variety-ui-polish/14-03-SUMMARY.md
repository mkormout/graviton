---
phase: 14-enemy-balancing-wave-variety-ui-polish
plan: "03"
subsystem: wave-ui
tags: [wave-manager, wave-hud, ui, signals, tween]
one_liner: "Manual wave-clear flow via wave_cleared_waiting signal, persistent WaveClearLabel, 72px announcement with 0.3s/2s/1s tween sequence"

dependency_graph:
  requires: [14-01, 14-02]
  provides:
    - "WaveManager emits wave_cleared_waiting instead of auto-starting countdown"
    - "WaveHud persistent WaveClearLabel shown on wave completion"
    - "Announcement label 72px with fade-in/hold/fade-out tween"
    - "speed_tier injection into _spawn_enemy for Swarmer groups"
  affects:
    - components/wave-manager.gd
    - prefabs/ui/wave-hud.gd
    - prefabs/ui/wave-hud.tscn

tech_stack:
  added: []
  patterns:
    - "Tween kill-before-recreate pattern (from score-hud.gd)"
    - "Signal-driven wave-clear flow (wave_cleared_waiting)"
    - "speed_tier set before add_child so _ready() receives it"

key_files:
  created: []
  modified:
    - components/wave-manager.gd
    - prefabs/ui/wave-hud.gd
    - prefabs/ui/wave-hud.tscn

decisions:
  - "countdown_tick signal kept declared in WaveManager (never emits) to avoid breaking WaveHud connection until it is removed in a future cleanup"
  - "WaveClearLabel offset_top = 20 (below center) to avoid overlapping AnnouncementLabel at offset_top = -60"
  - "speed_tier set before add_child because Swarmer reads it in _ready() which fires on add_child"

metrics:
  duration_minutes: 8
  completed_date: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
  files_created: 0
---

# Phase 14 Plan 03: Wave-Clear Flow Refactor and UI Polish Summary

Manual wave-clear flow via wave_cleared_waiting signal, persistent WaveClearLabel, 72px announcement with 0.3s/2s/1s tween sequence.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Refactor WaveManager — remove countdown, add wave_cleared_waiting signal, speed_tier injection | 04b2493 | components/wave-manager.gd |
| 2 | Add WaveClearLabel to wave-hud.tscn, update announcement font to 72px, add wave-clear handler and improved tween to wave-hud.gd | 58ce514 | prefabs/ui/wave-hud.tscn, prefabs/ui/wave-hud.gd |

## What Was Built

### Task 1: WaveManager Refactor

**components/wave-manager.gd:**
- Added `signal wave_cleared_waiting(wave_number: int)` after the existing signal declarations
- Removed `@export var countdown_seconds: float = 5.0`
- Removed `var _countdown_remaining: int` and `var _countdown_timer: Timer` instance vars
- Simplified `_ready()` to only `call_deferred("_find_player")` — no Timer setup
- Removed the entire `_on_countdown_tick()` method
- Replaced countdown start in `_on_wave_complete()` with `wave_cleared_waiting.emit(_current_wave_index)` in the else branch
- Removed countdown stop lines from `trigger_wave()`
- Added `speed_tier: float = 1.0` parameter to `_spawn_enemy()`, set before `get_parent().add_child(enemy)`
- Updated trigger_wave group loop to extract `speed_tier` from group dict and pass to `_spawn_enemy`
- `countdown_tick` signal remains declared (never emits) to avoid breaking WaveHud until future cleanup

### Task 2: WaveHud Updates

**prefabs/ui/wave-hud.tscn:**
- Changed AnnouncementLabel `font_size` from 48 to 72
- Added `WaveClearLabel` node as CanvasLayer direct child (sibling of Panel and AnnouncementLabel): centered slightly below center (offset_top=20), 48px font, outline size 3, black outline, `visible = false`

**prefabs/ui/wave-hud.gd:**
- Added `@onready var _wave_clear_label: Label = $WaveClearLabel`
- Added `var _announce_tween: Tween = null` instance var for tween kill-before-recreate pattern
- `_ready()` now also sets `_wave_clear_label.visible = false`
- `connect_to_wave_manager` now connects `wave_completed` and `wave_cleared_waiting` signals
- `_on_wave_started` hides `_wave_clear_label` first, then uses the new tween: 0.3s fade-in → 2s hold → 1s fade-out (replaces old 3s simple fade-out)
- Added `_on_wave_completed(_wave_number)` — hides wave-clear label (cleanup for next wave start)
- Added `_on_wave_cleared_waiting(wave_number)` — sets text and shows wave-clear label
- Added `hide_wave_clear_label()` — public method for world.gd wiring

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. `hide_wave_clear_label()` is a public method ready for world.gd to call when the player presses Enter or F. The actual world.gd wiring is deferred to plan 14-04.

## Threat Flags

None — signal-based communication between GDScript nodes; no new network endpoints, auth paths, file access, or schema changes at trust boundaries.

## Self-Check: PASSED

- components/wave-manager.gd: FOUND (wave_cleared_waiting signal at line 9)
- prefabs/ui/wave-hud.gd: FOUND (_wave_clear_label onready, _announce_tween, hide_wave_clear_label)
- prefabs/ui/wave-hud.tscn: FOUND (WaveClearLabel node, font_size=72 for AnnouncementLabel)
- Commit 04b2493 (Task 1): FOUND
- Commit 58ce514 (Task 2): FOUND
