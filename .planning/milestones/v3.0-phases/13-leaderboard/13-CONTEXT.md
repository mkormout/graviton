# Phase 13: Leaderboard - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

On player death: pause the game, show a name-entry overlay, record the score in a persistent top-10 table (ConfigFile on disk), then display the full leaderboard with the current run's row highlighted. No restart button or main-menu transition — this phase ends at the leaderboard display.

</domain>

<decisions>
## Implementation Decisions

### Death screen trigger
- **D-01:** Connect to the player `Body.died` signal (already exists on `Body`). When the player ship dies, call `get_tree().paused = true` to freeze physics and enemies.
- **D-02:** Show the death overlay (CanvasLayer, `process_mode = PROCESS_MODE_ALWAYS` so it receives input while paused). Name entry appears first; leaderboard is revealed after submission.
- **D-03:** The player ship's `died` signal is emitted just before `queue_free()` — the handler in `world.gd` (or a dedicated DeathScreen node) catches it and triggers the overlay.

### Name entry
- **D-04:** Single `LineEdit` node, max 16 characters. Confirm with Enter key or a Submit button — either works.
- **D-05:** If left blank, save the score with name `"---"` (no blocking, no required field). Blank = anonymous run.
- **D-06:** Pre-fill the LineEdit with the last used name, persisted alongside the leaderboard data in the same ConfigFile.
- **D-07:** After submission, immediately show the leaderboard table. No intermediate "saving…" state needed.

### Leaderboard layout
- **D-08:** Three columns: Rank | Name | Score. Top 10 entries only.
- **D-09:** Current run's row highlighted with gold text color (`Color(1.0, 0.843, 0.0)` — same gold used in ScoreManager and multiplier pulse). All other rows use white text with black outline (matching wave-hud / score-hud style).
- **D-10:** If the current run did not place in the top 10, show it below the table as an 11th unranked row, still highlighted gold, so the player always sees their score contextualised.
- **D-11:** Visual style: CanvasLayer, bare labels (no panel background), matching the established HUD pattern from Phase 12.
- **D-12:** A "GAME OVER" title label above the name entry, and a "HIGH SCORES" title above the leaderboard table.

### Persistence
- **D-13:** Use Godot's `ConfigFile` API, saved to `user://leaderboard.cfg`. Entries stored as `[scores] / entry_N = { name, score }` for N in 0..9.
- **D-14:** Last player name stored as `[prefs] / last_name = "..."` in the same file.
- **D-15:** On each new run submission, insert into the sorted list, truncate to top 10, and re-save.

### Claude's Discretion
- Exact font sizes and column widths for the leaderboard table
- Whether the leaderboard uses a `VBoxContainer` of `HBoxContainer` rows or a `GridContainer`
- Exact padding/spacing between name entry and leaderboard sections

</decisions>

<specifics>
## Specific Ideas

- Layout mockup confirmed by user:
  ```
  RANK  NAME          SCORE
  ─────────────────────────
  1     ACE           12,400
  2     BOB            9,100
  »3    YOU ←          7,800   ← highlighted gold
  4     ---            4,200
  5     ZAP            3,500
  ```
- The `»` marker and `←` arrow are optional flourishes — the gold color is the primary highlight mechanism.

</specifics>

<canonical_refs>
## Canonical References

No external specs or ADRs exist for this phase. Requirements are fully captured in decisions above and the files below.

### Existing code to read
- `components/body.gd` — `died` signal, `die()` method; death overlay must connect to player's `died` before `queue_free()` runs
- `components/score-manager.gd` — Autoload; exposes `score` property (final score to save)
- `prefabs/ui/wave-hud.gd` and `prefabs/ui/wave-hud.tscn` — CanvasLayer + bare-label pattern to follow for death overlay
- `prefabs/ui/score-hud.gd` — `connect_to_score_manager()` wiring pattern; death screen may follow same init convention
- `world.gd` — Where `ShipBFG23.died` signal should be connected; existing pattern for connecting to player node via group `"player"`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Body.died` signal — already fires on player death; no new signal needed
- `ScoreManager` autoload — `ScoreManager.score` gives the final score directly
- `Color(1.0, 0.843, 0.0)` gold — already used in ScoreManager `_combo_color()` and score-hud multiplier pulse; reuse for leaderboard highlight

### Established Patterns
- CanvasLayer with `process_mode = PROCESS_MODE_ALWAYS` — required for UI to receive input while `get_tree().paused = true`
- Bare labels (no Panel background) — established in wave-hud and score-hud; continue here
- `connect_to_X(manager)` init method — wave-hud and score-hud both use this pattern; death screen should expose `show_death_screen(score_manager)` or similar
- White text + black outline — `theme_override_colors/font_color = Color(1,1,1,1)` + `theme_override_constants/outline_size = 3`

### Integration Points
- `world.gd` — Connect `$ShipBFG23.died` to a handler that calls `death_screen.show_death_screen(ScoreManager)`
- `project.godot` — No new autoload needed; DeathScreen is a child node in `world.tscn`
- `user://leaderboard.cfg` — New file; created on first death if absent

</code_context>

<deferred>
## Deferred Ideas

- Restart button / return to menu — no menu exists yet; deferred to Phase 14 or later
- Online leaderboard — out of scope
- Multiple difficulty tiers with separate tables — out of scope

</deferred>

---

*Phase: 13-leaderboard*
*Context gathered: 2026-04-15*
