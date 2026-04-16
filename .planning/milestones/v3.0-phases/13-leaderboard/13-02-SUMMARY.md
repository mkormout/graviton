---
phase: 13-leaderboard
plan: 02
subsystem: world
tags: [godot, world-wiring, death-screen, pause, signal, gdscript]

requires:
  - phase: 13-leaderboard
    plan: 01
    provides: DeathScreen CanvasLayer scene with show_death_screen(score) public API

provides:
  - world.gd wired to instantiate DeathScreen on startup
  - $ShipBFG23.died signal connected to _on_player_died handler
  - Tree pause on player death (get_tree().paused = true)
  - Death screen triggered with ScoreManager.total_score on player death

affects: [world.gd]

tech-stack:
  added: []
  patterns:
    - "Signal connection: $ShipBFG23.died.connect(_on_player_died) in _ready()"
    - "Tree pause before overlay: get_tree().paused = true followed by show_death_screen"
    - "preload pattern for UI scenes: var death_screen_model = preload(res://prefabs/ui/death-screen.tscn)"

key-files:
  created: []
  modified:
    - world.gd

key-decisions:
  - "Signal connected in _ready() after enemy_radar instantiation — consistent with other UI wiring order"
  - "get_tree().paused = true called before show_death_screen so tree is paused before overlay input is processed"
  - "ScoreManager.total_score used (not .score) per RESEARCH.md Pitfall 3"

requirements-completed: [SCR-09, SCR-11]

duration: <1min
completed: 2026-04-15
---

# Phase 13 Plan 02: Wire death screen into world.gd — preload, instantiate, connect died signal, pause on death

**world.gd modified to instantiate DeathScreen CanvasLayer, connect $ShipBFG23.died signal, pause the tree on player death, and call show_death_screen(ScoreManager.total_score) to trigger the overlay.**

## Performance

- **Duration:** <1 min
- **Started:** 2026-04-15T19:42:00Z
- **Completed:** 2026-04-15T19:43:12Z
- **Tasks:** 1/2 (Task 2 is a human-verify checkpoint — awaiting verification)
- **Files modified:** 1

## Accomplishments

### Task 1 — Wire death screen in world.gd

Modified `world.gd` with 4 targeted additions:

1. **Preload** (after existing UI model preloads at line 17):
   ```gdscript
   var death_screen_model = preload("res://prefabs/ui/death-screen.tscn")
   ```

2. **Instance variable** (after `camera_follow`):
   ```gdscript
   var death_screen: DeathScreen = null
   ```

3. **_ready() wiring** (after `add_child(enemy_radar_model.instantiate())`):
   ```gdscript
   death_screen = death_screen_model.instantiate()
   add_child(death_screen)
   $ShipBFG23.died.connect(_on_player_died)
   ```

4. **Signal handler** (at end of file):
   ```gdscript
   func _on_player_died() -> void:
       get_tree().paused = true
       death_screen.show_death_screen(ScoreManager.total_score)
   ```

All existing world.gd code left unchanged — wave_hud_model, score_hud_model, enemy_radar_model preloads all intact.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all functional paths are implemented. The death screen is fully wired.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns beyond what was specified in the plan's threat model. The pause mechanic (T-13-06) is an intentional game mechanic.

## Checkpoint: Task 2 — Human Verification Pending

Task 2 is a `checkpoint:human-verify` gate. The human must run the game in Godot 4.6.2 and verify the complete death flow:

1. Player death triggers game pause and death screen overlay
2. Name entry accepts input, Enter/button submits
3. Leaderboard table shows entries sorted by score with gold highlighting
4. Scores persist across game restarts (ConfigFile at user://leaderboard.cfg)
5. Last name pre-fills on subsequent deaths

**Verification steps from the plan:**
- Test 1: First death — basic flow (F to trigger wave, wait for death, enter name, check leaderboard)
- Test 2: Second death — pre-fill and ranking
- Test 3: Blank name saves as "---"
- Test 4: Persistence across restarts
- Test 5: Not-in-top-10 unranked row (optional, requires 10 entries)

## Self-Check: PASSED

- `world.gd` exists: FOUND
- Commit 93dc287 (Task 1 — wire death screen): FOUND
- `death_screen_model` preload in world.gd: FOUND (2 matches — declaration and usage)
- `death-screen.tscn` reference in world.gd: FOUND
- `_on_player_died` in world.gd: FOUND (2 matches — definition and connection)
- `get_tree().paused = true` in world.gd: FOUND
- `ScoreManager.total_score` in world.gd: FOUND
- `ShipBFG23.died.connect` in world.gd: FOUND
- No bare `ScoreManager.score` (wrong property): CONFIRMED ABSENT
