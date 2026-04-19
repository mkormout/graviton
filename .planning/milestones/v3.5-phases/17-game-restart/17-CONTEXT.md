# Phase 17: Game Restart - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Players can click "Play Again" on the death screen to restart the full game. All systems (wave, score, music, enemies, world) reset to the exact state they were in at app launch — without reloading the application. Phase ends when the button exists, restarts feel clean, and all four systems (WaveManager, ScoreManager, MusicManager, world) are correctly reset.

No new gameplay, no difficulty selection, no UI redesign beyond the Play Again button.

</domain>

<decisions>
## Implementation Decisions

### Play Again Button Placement
- **D-01:** "Play Again" button appears only after the leaderboard is displayed — i.e., after the player has submitted their name and seen the scores. It is added to the LeaderboardSection, below the score table.
- **D-02:** No skip-to-restart before score submission. The flow is: name entry → submit → leaderboard → Play Again.

### World Cleanup on Restart
- **D-03:** Full world reset — mirrors the initial state of `_ready()` as closely as possible. Specifically:
  - All enemies (`"enemy"` group) are `queue_free()`'d
  - All item drops (Item nodes / `"item"` group if one exists, otherwise find by class) are `queue_free()`'d
  - All existing asteroids are `queue_free()`'d
  - Fresh asteroids are respawned via `spawn_asteroids(100)` (same call as in `_ready()`)
- **D-04:** The game world after restart should feel indistinguishable from a fresh app launch.

### Player Ship Reset
- **D-05:** Player ship (`$ShipBFG23`) is reset to `global_position = Vector2.ZERO`, `linear_velocity = Vector2.ZERO`, `angular_velocity = 0.0`, and `health = max_health`.
- **D-06:** The ship is never removed from the scene — it stays as a permanent child of world. Only its state is reset.

### System Reset Sequence
- **D-07:** Death screen emits a signal (e.g., `play_again_requested`) when Play Again is clicked. `world.gd` handles the full reset sequence in one method (`_restart_game()`).
- **D-08:** Reset order: unpause tree → clear world (enemies, items, asteroids) → reset player → call `ScoreManager.reset()` → call `WaveManager.reset()` → call `MusicManager.reset()` → respawn asteroids → trigger first wave.
- **D-09:** `WaveManager.reset()` must zero `_current_wave_index`, `_enemies_alive`, and `_wave_total` so Wave 1 starts cleanly. It does NOT auto-trigger the first wave — that remains a manual call (same as app start).
- **D-10:** `ScoreManager.reset()` must zero `total_score`, `kill_count`, and reset `wave_multiplier` to 1.
- **D-11:** `MusicManager.reset()` already required by Phase 16 (D-09) — restores Ambient category and restarts playback from Wave 1 state.

### Claude's Discretion
- Exact signal name on DeathScreen
- Whether to use `call_deferred` vs direct calls during unpause
- How asteroids are identified for cleanup (node group or class check)
- Whether item drops need a group tag added or can be cleared by class

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Death screen (current implementation)
- `prefabs/ui/death-screen.gd` — Current death screen: name entry → submit → leaderboard. "Play Again" button must be added to LeaderboardSection. No restart logic exists yet.

### World orchestration
- `world.gd` — `_on_player_died()` (line ~395) pauses the tree and calls `death_screen.show_death_screen()`. `_restart_game()` will be a new method here. Also contains `spawn_asteroids(100)` (line ~385 area) which must be re-called on restart.

### Systems to add reset() to
- `components/wave-manager.gd` — `_current_wave_index`, `_enemies_alive`, `_wave_total` must be zeroed in a new `reset()` method.
- `components/score-manager.gd` — `total_score`, `kill_count`, `wave_multiplier` must be zeroed/reset in a new `reset()` method.
- `components/music-manager.gd` — `reset()` already specified by Phase 16 D-09; must restore Ambient category and Wave 1 playback state.

### Requirements
- `.planning/REQUIREMENTS.md` — UI-05, UI-06, UI-07 define the acceptance criteria for this phase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DeathScreen` (`prefabs/ui/death-screen.gd`) — Has `_name_section` and `_leaderboard_section` Control nodes. Play Again button goes into `_leaderboard_section`. `_submitted` flag guards duplicate submissions.
- `spawn_asteroids(count)` in `world.gd` — Already exists; re-call with 100 on restart.
- `get_tree().get_nodes_in_group("enemy")` — Existing enemy group; use for cleanup loop.

### Established Patterns
- Autoload reset pattern: ScoreManager and MusicManager are autoloads (`extends Node`). Add `reset()` method following the same pattern as their existing state initialization in `_ready()`.
- Signal wiring: `world.gd` already connects to DeathScreen implicitly (calls `show_death_screen`). Add signal from DeathScreen → world.gd for restart.
- `call_deferred` for autoload-to-scene timing — used in ScoreManager and MusicManager; same pattern applies if reset needs deferred calls.

### Integration Points
- `world.gd._on_player_died()` — Entry point for death; restart reverses this.
- `world.gd._ready()` — Reference for what "initial state" looks like (asteroid spawn, wave wiring, player setup).
- `get_tree().paused` — Set to true on death; must be set false at restart start.

</code_context>

<specifics>
## Specific Ideas

- "The game should start similarly to how the application starts" — restart is a soft relaunch, not a partial reset.
- The Play Again button label can evolve in a future phase (difficulty settings dialog), but for now it's a simple "Play Again" label.

</specifics>

<deferred>
## Deferred Ideas

- **Difficulty settings phase** — User wants a "Start New Game" dialog with difficulty selection options (easy/medium/hard or similar). The Play Again button is a good entry point for this future dialog. Add as its own phase in the backlog after v3.5.

</deferred>

---

*Phase: 17-game-restart*
*Context gathered: 2026-04-18*
