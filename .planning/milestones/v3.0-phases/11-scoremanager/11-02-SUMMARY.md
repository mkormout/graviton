---
phase: 11-scoremanager
plan: 02
subsystem: scoring
tags: [gdscript, autoload, audio, signals, godot4, wave-manager, score-manager, combo]

# Dependency graph
requires:
  - "11-01: Body.died() signal, Body.health_changed() signal, EnemyShip.score_value export, WaveManager.wave_completed signal, ScoreManager autoload registered"
provides:
  - "ScoreManager singleton: kill scoring, wave multiplier, combo chain, combo audio"
  - "WaveManager registers each spawned enemy with ScoreManager"
  - "world.gd wires ScoreManager to WaveManager on startup"
  - "All 5 enemy types have explicit score_value in their .tscn files"
affects:
  - "Phase 12: HUD display of score, multiplier, combo (reads ScoreManager signals)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Autoload singleton pattern: ScoreManager extends Node, registered in project.godot"
    - "Timer.new() programmatic creation for combo timeout (matches MountableWeapon pattern)"
    - "AudioStreamPlayer.new() with preload() for non-positional audio"
    - "call_deferred('_find_player') for autoload-safe player lookup"
    - "enemy.died.connect(_on_enemy_died.bind(enemy)) for typed signal binding"
    - "if ScoreManager: guard for backward-compatible autoload access"

key-files:
  created:
    - components/score-manager.gd
  modified:
    - components/wave-manager.gd
    - world.gd
    - prefabs/enemies/beeliner/beeliner.tscn
    - prefabs/enemies/sniper/sniper.tscn
    - prefabs/enemies/flanker/flanker.tscn
    - prefabs/enemies/swarmer/swarmer.tscn
    - prefabs/enemies/suicider/suicider.tscn

key-decisions:
  - "combo_count 2 uses pitch pow(1.0595, 0) = 1.0 (exponent is combo_count - 2, not combo_count - 1 as D-13 formula states — concrete examples take priority)"
  - "if ScoreManager: guard in WaveManager and world.gd ensures backward compatibility if autoload is removed"
  - "register_enemy placed BEFORE get_parent().add_child(enemy) so signal is wired before the enemy is in the tree (no race window)"

requirements-completed: [SCR-03, SCR-04, SCR-06, SCR-07, SCR-08]

# Metrics
duration: 12min
completed: 2026-04-14
---

# Phase 11 Plan 02: ScoreManager Implementation Summary

**ScoreManager autoload singleton with kill scoring, wave multiplier (x1-x16), 5-second combo chain with semitone audio, and complete WaveManager + enemy wiring**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-14T21:17:22Z
- **Completed:** 2026-04-14T21:29:00Z
- **Tasks:** 2
- **Files modified:** 7 modified, 1 created

## Accomplishments

- `components/score-manager.gd` created as a 147-line autoload singleton
- Kill scoring: `base_score * wave_multiplier` added to `total_score` on every enemy death
- Wave multiplier: doubles on `wave_completed` signal (x1→x2→x4→x8→x16 cap), resets to x1 on player damage
- Combo chain: 5-second Timer, first kill starts chain silently, kills 2+ play semitone-stepped combo.wav, expiry awards `combo_count * 25 * wave_multiplier` bonus
- All scoring events emit print output for console verification (Phase 12 verification method)
- WaveManager calls `ScoreManager.register_enemy(enemy)` before `add_child` so the `died` signal is wired before the enemy enters the scene tree
- `world.gd` calls `ScoreManager.connect_to_wave_manager($WaveManager)` in `_ready()` after wave HUD wiring
- Beeliner=100, Swarmer=50, Flanker=150, Sniper=200, Suicider=75 set explicitly in `.tscn` root nodes

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ScoreManager autoload** - `ae45062` (feat)
2. **Chore: Restore soft-reset deleted files, add combo.wav** - `2f60bdc` (chore) [deviation — see below]
3. **Task 2: Wire ScoreManager into WaveManager and world.gd, set enemy score_value** - `575dfbc` (feat)

## Files Created/Modified

- `components/score-manager.gd` — New 147-line autoload: 4 signals, 3 constants, kill scoring, combo chain, wave multiplier, semitone audio
- `components/wave-manager.gd` — Added `ScoreManager.register_enemy(enemy)` in `_spawn_enemy()` before `add_child`, guarded by `if ScoreManager:`
- `world.gd` — Added `ScoreManager.connect_to_wave_manager($WaveManager)` in `_ready()` after wave HUD wiring, guarded by `if ScoreManager:`
- `prefabs/enemies/beeliner/beeliner.tscn` — Added `score_value = 100` on root node
- `prefabs/enemies/sniper/sniper.tscn` — Added `score_value = 200` on root node
- `prefabs/enemies/flanker/flanker.tscn` — Added `score_value = 150` on root node
- `prefabs/enemies/swarmer/swarmer.tscn` — Added `score_value = 50` on root node
- `prefabs/enemies/suicider/suicider.tscn` — Added `score_value = 75` on root node

## Decisions Made

- Combo pitch uses `pow(1.0595, combo_count - 2)` not `combo_count - 1`: D-13 specifies "kill 2 = base pitch (1.0)" which requires exponent 0 at combo_count=2, contradicting the formula in D-13. Concrete behavior specification takes priority.
- `register_enemy()` placed before `add_child()` in `_spawn_enemy()` to close the race window where the enemy could die in `_ready()` before the signal was connected.
- Both autoload calls use `if ScoreManager:` guard for backward compatibility.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Restored files deleted by soft-reset staging area**
- **Found during:** Task 1 commit
- **Issue:** `git reset --soft` to the correct base commit left staged changes in the index that deleted pre-existing files (health-pack resources, 10-health-pack planning docs, 11-scoremanager context files, sounds/combo.wav.import). These were committed as deletions alongside Task 1.
- **Fix:** After Task 1 commit, checked out the deleted files from `81d9048` and committed a restoration chore commit. Also copied `combo.wav` from main project directory to the worktree since it was untracked.
- **Files modified:** `.planning/phases/10-health-pack-foundation/` (7 files), `.planning/phases/11-scoremanager/` (6 context files), `items/health-pack.tres`, `prefabs/health-pack/health-pack.tscn`, `sounds/combo.wav`
- **Commit:** `2f60bdc`

## Issues Encountered

The worktree's `git reset --soft` to the correct base commit had an unexpected side effect: staged changes from uncommitted work in the main worktree were carried into the staging index, causing pre-existing files to appear as staged deletions. These were restored in a separate chore commit.

## User Setup Required

None — no external service configuration required. All scoring behavior is verifiable via Godot console print output when playing the game.

## Known Stubs

None — all signals emit real data. Score values, multiplier, and combo bonuses are all computed from live game state. No placeholder values.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced. All additions are in-process game logic.

## Next Phase Readiness

- Phase 12 can now wire ScoreManager signals (`score_changed`, `multiplier_changed`, `combo_updated`, `combo_expired`) to HUD display nodes
- Console verification of scoring behavior is available immediately by running the game and triggering enemy spawns with KEY_F

---

## Self-Check: PASSED

- FOUND: `.planning/phases/11-scoremanager/11-02-SUMMARY.md`
- FOUND: `components/score-manager.gd`
- FOUND: commit `ae45062` (Task 1: ScoreManager creation)
- FOUND: commit `2f60bdc` (Chore: restore soft-reset deletions)
- FOUND: commit `575dfbc` (Task 2: WaveManager wiring + enemy score_value)
