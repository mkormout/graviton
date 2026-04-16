# Phase 11: ScoreManager - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement ScoreManager as a backend-only system: kill scoring, wave multiplier, and combo chain. No HUD wiring in this phase — correctness is verified via print output. Phase 12 will wire the HUD to ScoreManager signals.

</domain>

<decisions>
## Implementation Decisions

### ScoreManager placement
- **D-01:** ScoreManager is an **autoload singleton** registered in `project.godot`. Globally accessible from HUD (Phase 12), Leaderboard (Phase 13), and anywhere else without scene coupling.

### Kill detection
- **D-02:** Add a **`died` signal** to `Body.gd` fired inside `die()`. EnemyShip (or the scene) is the sender; ScoreManager connects to each spawned enemy's `died` signal.
- **D-03:** Add a **`health_changed(old_health: int, new_health: int)` signal** to `Body.gd` fired inside `damage()` when net damage is negative (health decreases). ScoreManager connects to the player's signal to detect damage and reset the wave multiplier.
- Both signals added to `Body` in a single pass — no separate signal pattern for PlayerShip.

### Enemy point values
- **D-04:** Add `@export var score_value: int = 100` to `EnemyShip` base class. Each enemy scene overrides in the Inspector.
- **D-05:** Initial values (subject to Phase 14 re-balancing):
  - Beeliner = 100
  - Swarmer = 50
  - Flanker = 150
  - Sniper = 200
  - Suicider = 75

### Wave multiplier
- **D-06:** Multiplier follows the success criteria exactly: ×1 → ×2 → ×4 → ×8 → ×16 (cap). Doubles on each wave completed without taking damage.
- **D-07:** Reset to ×1 on any player damage (detected via `health_changed` signal on player Body).
- **D-08:** ScoreManager listens to `WaveManager.all_waves_complete` (and per-wave completion) to advance the multiplier.

### Combo chain
- **D-09:** Combo counter starts at 0. First kill = 0 (no combo); second kill within 5 seconds of first = combo of 2; each subsequent kill within 5 seconds of the last extends the chain.
- **D-10:** Combo expires after **5 seconds** of no kills. On expiry, award a combo bonus score.
- **D-11:** Combo bonus = combo_count × 25 points (flat bonus per kill in chain, multiplied by active wave multiplier).

### Combo audio
- **D-12:** Use `sounds/combo.wav` as the combo sound.
- **D-13:** Pitch progression: **semitone steps** — `pitch_scale = pow(1.0595, combo_count - 1)`. Combo kill 2 = 1.0 (base pitch), kill 3 = 1.0595, kill 4 = 1.12, etc.
- **D-14:** Played via `AudioStreamPlayer` (non-positional) on ScoreManager node itself — combo audio is UI feedback, not spatial.

### Claude's Discretion
- Exact ScoreManager signal names for Phase 12 HUD (e.g., `score_changed`, `multiplier_changed`, `combo_updated`)
- Whether combo timer uses a Godot `Timer` node or `_process` delta accumulation
- Whether wave multiplier advancement hooks via `WaveManager.wave_started` or a new signal
- Exact combo bonus formula fine-tuning within the spirit of D-11

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs or ADRs. Requirements are captured in decisions above and the files below.

### Core systems to modify
- `components/body.gd` — Add `died` and `health_changed` signals here
- `components/enemy-ship.gd` — Add `@export var score_value: int` here
- `components/wave-manager.gd` — ScoreManager listens to `wave_started` / `all_waves_complete` signals

### Enemy scenes (score_value to set per scene)
- `prefabs/enemies/beeliner/beeliner.tscn` — score_value = 100
- `prefabs/enemies/sniper/sniper.tscn` — score_value = 200
- `prefabs/enemies/flanker/flanker.tscn` — score_value = 150
- `prefabs/enemies/swarmer/swarmer.tscn` — score_value = 50
- `prefabs/enemies/suicider/suicider.tscn` — score_value = 75

### World wiring
- `world.gd` — Player node, WaveManager reference; ScoreManager connects to player `health_changed` and WaveManager signals here (or in ScoreManager._ready via group lookup)

### Audio
- `sounds/combo.wav` — Combo kill sound; played at semitone pitch steps per combo count

### Phase success criteria
- Kill scoring verifiable via print: `[ScoreManager] Kill: Sniper +200 (×2) = 400 total: 1250`
- Wave multiplier verifiable: `[ScoreManager] Wave complete, multiplier ×2`
- Combo verifiable: `[ScoreManager] Combo x3 expires, bonus +75`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RandomAudioPlayer` (`components/random-audio-player.gd`): Wraps `AudioStreamPlayer2D`; ScoreManager needs a non-positional `AudioStreamPlayer` instead — don't reuse directly, but the pattern is similar
- `WaveManager` signals (`wave_started`, `enemy_count_changed`, `all_waves_complete`, `countdown_tick`): `all_waves_complete` fires when all waves are done; individual wave completion fires in `_on_wave_complete()` but no signal exists for it yet — add `wave_completed(wave_number: int)` signal to WaveManager

### Established Patterns
- Autoloads: None exist yet — this is the first. Register in `project.godot` under `[autoload]` section
- Enemy tuning via @export: `max_speed`, `thrust`, `detection_radius` are all @export on EnemyShip, tuned per-scene in Inspector — follow same pattern for `score_value`
- Signals: `Body` has no signals today; `WaveManager` emits 4 signals — follow WaveManager pattern (typed parameters, emitted at action site)

### Integration Points
- `Body.die()` — Add `died.emit()` before `queue_free()`
- `Body.damage()` — Add `health_changed.emit(old_health, health)` after health update when damage is negative
- `WaveManager._on_wave_complete()` — Add `wave_completed.emit(_current_wave_index)` signal emission
- `world.gd` — ScoreManager is autoload, connects to player `health_changed` in its own `_ready()` using `get_tree().get_first_node_in_group("player")`

</code_context>

<specifics>
## Specific Ideas

- Print format for kill verification: `[ScoreManager] Kill: {enemy_type} +{base} (×{multiplier}) = {kill_score} | total: {total_score}`
- Multiplier should also emit a signal on change so Phase 12 HUD can update the display

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-scoremanager*
*Context gathered: 2026-04-14*
