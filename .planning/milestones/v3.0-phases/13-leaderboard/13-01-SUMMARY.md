---
phase: 13-leaderboard
plan: 01
subsystem: ui
tags: [godot, canvaslayer, configfile, leaderboard, death-screen, gdscript]

requires:
  - phase: 12-score-hud
    provides: ScoreManager.total_score autoload, score_changed signal, HUD CanvasLayer pattern

provides:
  - DeathScreen CanvasLayer scene (prefabs/ui/death-screen.tscn) with process_mode=PROCESS_MODE_ALWAYS at layer 20
  - DeathScreen GDScript class (prefabs/ui/death-screen.gd) with show_death_screen(score) public API
  - ConfigFile persistence at user://leaderboard.cfg with [scores]/entry_N dictionaries and [prefs]/last_name
  - Two-stage death overlay: name entry (Stage 1) and leaderboard display (Stage 2)
  - Gold highlight for current run row; unranked 11th row when not in top-10

affects: [13-02-PLAN, world.gd integration]

tech-stack:
  added: []
  patterns:
    - "DeathScreen: CanvasLayer with process_mode=3 (PROCESS_MODE_ALWAYS) for pause-safe input"
    - "ConfigFile persistence: user:// path, sections [scores] + [prefs], graceful load-miss handling"
    - "Two-stage overlay: NameSection/LeaderboardSection visibility toggle, no animation"
    - "_submitted bool guard prevents double-submit from simultaneous Enter + button press"
    - "call_deferred('grab_focus') for deferred focus after visible=true"

key-files:
  created:
    - prefabs/ui/death-screen.gd
    - prefabs/ui/death-screen.tscn
  modified: []

key-decisions:
  - "process_mode=PROCESS_MODE_ALWAYS set on CanvasLayer root (not children) for pause-safe input"
  - "VBoxContainer of HBoxContainer rows for leaderboard table (simpler per-row color control vs GridContainer)"
  - "_submitted bool guard prevents duplicate entry insertion on double-Enter or Enter+button same frame"
  - "call_deferred('grab_focus') required — synchronous call silently fails when node just became visible"
  - "ConfigFile load-miss returns [] gracefully — first run has no leaderboard.cfg yet"

patterns-established:
  - "DeathScreen.show_death_screen(score: int): public API called by world.gd to trigger overlay"
  - "Stage transition: _name_section.visible=false, _leaderboard_section.visible=true on submit"
  - "_add_row creates HBoxContainer with 3 Labels, applies theme_color_override for gold/white"

requirements-completed: [SCR-09, SCR-10, SCR-11]

duration: 2min
completed: 2026-04-15
---

# Phase 13 Plan 01: Death Screen — ConfigFile leaderboard with name entry, gold highlight, and pause-safe CanvasLayer overlay

**DeathScreen CanvasLayer scene (layer 20, PROCESS_MODE_ALWAYS) with two-stage death flow: name entry via LineEdit/Button → ConfigFile save → top-10 leaderboard table with gold current-run row.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-15T19:34:15Z
- **Completed:** 2026-04-15T19:36:28Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

### Task 1 — death-screen.gd

Created `prefabs/ui/death-screen.gd` with the complete `DeathScreen` class:

- `show_death_screen(score: int)` public API: sets `visible = true`, pre-fills last name, deferred focus
- `_on_submit` handler with `_submitted` bool guard (T-13-03 double-submit mitigation per threat model)
- `_load_entries()` / `_save_entries()` / `_insert_entry()`: ConfigFile persistence at `user://leaderboard.cfg`
- `_load_last_name()`: retrieves `[prefs]/last_name` for pre-fill on next death
- `_populate_table(entries)`: clears rows, renders up to 10 entries with gold/white coloring; adds separator + unranked 11th gold row when `_current_entry_index == -1`
- `_add_row(rank, name, score, color)`: creates HBoxContainer with 3 Labels at 18px with black outline, proper min-widths (48/224/128), score right-aligned

### Task 2 — death-screen.tscn

Created `prefabs/ui/death-screen.tscn` as a valid Godot 4 scene file:

- CanvasLayer root: `layer = 20`, `process_mode = 3`, `visible = false`, script attached
- Backdrop: fullscreen ColorRect at `Color(0, 0, 0, 0.72)` for readability over game scene
- NameSection: GAME OVER (64px gold), ENTER YOUR NAME (32px white), LineEdit (max_length=16), SAVE SCORE button
- LeaderboardSection (initially `visible = false`): GAME OVER title, HIGH SCORES heading, RANK/NAME/SCORE headers at 22px, HSeparator, empty RowsContainer
- All node paths match `@onready` references in `death-screen.gd` exactly

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all functional paths are implemented. The `RowsContainer` is intentionally empty at design time; rows are injected by `_populate_table()` at runtime.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns beyond what was specified in the plan's threat model.

## Self-Check: PASSED

- `prefabs/ui/death-screen.gd` exists: FOUND
- `prefabs/ui/death-screen.tscn` exists: FOUND
- Commit f57f3a8 (Task 1 — death-screen.gd): FOUND
- Commit 0895467 (Task 2 — death-screen.tscn): FOUND
