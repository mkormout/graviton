# Phase 17: Game Restart - Research

**Researched:** 2026-04-18
**Domain:** Godot 4 in-place game state reset (GDScript, single-scene architecture)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** "Play Again" button appears only after the leaderboard is displayed — i.e., after the player has submitted their name and seen the scores. It is added to the LeaderboardSection, below the score table.
- **D-02:** No skip-to-restart before score submission. The flow is: name entry → submit → leaderboard → Play Again.
- **D-03:** Full world reset — mirrors the initial state of `_ready()` as closely as possible. All enemies, item drops, and existing asteroids are `queue_free()`'d; fresh asteroids respawned via `spawn_asteroids(100)`.
- **D-04:** The game world after restart should feel indistinguishable from a fresh app launch.
- **D-05:** Player ship reset to `global_position = Vector2.ZERO`, `linear_velocity = Vector2.ZERO`, `angular_velocity = 0.0`, `health = max_health`.
- **D-06:** The ship is never removed from the scene — only its state is reset.
- **D-07:** Death screen emits a signal (e.g., `play_again_requested`) when Play Again is clicked. `world.gd` handles the full reset in `_restart_game()`.
- **D-08:** Reset order: unpause tree → clear world (enemies, items, asteroids) → reset player → `ScoreManager.reset()` → `WaveManager.reset()` → `MusicManager.reset()` → respawn asteroids → trigger first wave.
- **D-09:** `WaveManager.reset()` must zero `_current_wave_index`, `_enemies_alive`, `_wave_total`. Does NOT auto-trigger the first wave.
- **D-10:** `ScoreManager.reset()` must zero `total_score`, `kill_count`, reset `wave_multiplier` to 1.
- **D-11:** `MusicManager.reset()` already implemented by Phase 16 — restores Ambient category and restarts playback.

### Claude's Discretion
- Exact signal name on DeathScreen
- Whether to use `call_deferred` vs direct calls during unpause
- How asteroids are identified for cleanup (node group or class check)
- Whether item drops need a group tag added or can be cleared by class

### Deferred Ideas (OUT OF SCOPE)
- Difficulty settings phase — "Start New Game" dialog with difficulty selection. Deferred after v3.5.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-05 | Player can click "Play Again" on the death screen to restart without reloading the application | Signal from DeathScreen → world.gd `_restart_game()`; no scene reload needed |
| UI-06 | Restart resets wave to Wave 1, clears all living enemies, restores player to full health | WaveManager.reset() zeros index/count; enemy group cleanup; Body.health = max_health |
| UI-07 | Restart resets MusicManager to Ambient intensity | MusicManager.reset() already implemented in Phase 16 |
</phase_requirements>

---

## Summary

Phase 17 adds a "Play Again" button to the death screen's LeaderboardSection and wires a full in-place game reset through `world.gd`. The codebase is well-prepared: `MusicManager.reset()` already exists (Phase 16), the `"enemy"` group is already used by WaveManager, and `spawn_asteroids(100)` already exists in world.gd.

The primary technical work is: (1) add a signal and button to DeathScreen, (2) add `reset()` methods to WaveManager and ScoreManager, (3) implement `_restart_game()` in world.gd, and (4) handle three node-cleanup categories — enemies (group), items (class-based), asteroids (class-based). Items and asteroids have no group assigned today; the safest approach is class-based iteration using `is` checks.

One non-obvious pitfall exists: `Body.dying` is set to `true` when a body starts dying and is never reset. When the player ship has `dying = false` restored, and `health` is restored to `max_health`, the ship becomes killable again. This must be explicitly reset alongside `health`.

**Primary recommendation:** Use `get_tree().get_nodes_in_group("enemy")` for enemy cleanup. Use `get_children()` filtered by `is Asteroid` and `is Item` for asteroid/item cleanup. Add a `"bullet"` consideration — bullets are transient and typically self-destruct, but any in-flight at death time should also be cleared.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Play Again button + signal emission | DeathScreen (CanvasLayer) | — | UI owns the interaction; world receives the event |
| Restart orchestration | world.gd | — | world.gd owns the scene, all node references, and the pause state |
| Wave state reset | WaveManager (Node child of world) | — | WaveManager owns `_current_wave_index`, `_enemies_alive`, `_wave_total` |
| Score state reset | ScoreManager (Autoload) | — | ScoreManager is an autoload; its state survives any would-be scene reload |
| Music state reset | MusicManager (Autoload) | — | Already implemented; autoload owns the AudioStreamPlayer nodes |
| World cleanup (enemies, items, asteroids) | world.gd | — | world.gd is the spawn_parent for all dynamic nodes |
| Player ship state reset | world.gd acting on $ShipBFG23 | Body.dying flag | world.gd holds the $ShipBFG23 reference |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot 4.2.1 (project target) / 4.6.2 (migration) | 4.2.1 current | GDScript, scene tree, signal bus | Engine constraint — no external libraries |
| ConfigFile | built-in | Leaderboard persistence | Already used in death-screen.gd |

No external npm/pip dependencies. All tooling is built into the Godot engine.

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Godot `get_tree().get_nodes_in_group()` | built-in | Enemy cleanup | When nodes are pre-registered in a group |
| Godot `Node.get_children()` | built-in | Asteroid/item cleanup | When no group exists; filter by `is ClassName` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Class-based iteration for asteroids/items | Add them to groups first | Adding groups is cleaner long-term; class-based works today without scene changes |
| Direct method calls in `_restart_game()` | `call_deferred` | `call_deferred` safer when called while tree is paused; direct calls safe after `get_tree().paused = false` |

---

## Architecture Patterns

### System Architecture Diagram

```
[DeathScreen: CanvasLayer]
  LeaderboardSection visible
  → "Play Again" Button pressed
  → emit play_again_requested signal
           │
           ▼
[world.gd: _restart_game()]
  1. get_tree().paused = false
  2. death_screen.visible = false
  3. Clear enemies   ← get_tree().get_nodes_in_group("enemy") → queue_free()
  4. Clear items     ← get_children() filtered by is Item → queue_free()
  5. Clear asteroids ← get_children() filtered by is Asteroid → queue_free()
  6. Reset player    ← $ShipBFG23.{position, velocity, health, dying}
  7. ScoreManager.reset()
  8. WaveManager.reset()
  9. MusicManager.reset()
 10. spawn_asteroids(100)
 11. _wave_clear_pending = false
 12. $WaveManager.trigger_wave()    ← starts Wave 1
```

### Recommended Project Structure
No structural changes needed. All files modified are existing:
```
prefabs/ui/
├── death-screen.gd     # Add signal + Play Again button in _on_submit()
├── death-screen.tscn   # No change needed (button created in code)
components/
├── wave-manager.gd     # Add reset() method
├── score-manager.gd    # Add reset() method
├── music-manager.gd    # reset() already exists (Phase 16)
world.gd               # Add _restart_game() + connect death_screen signal in _ready()
```

### Pattern 1: Signal Emission from DeathScreen
**What:** DeathScreen emits `play_again_requested` when Play Again is clicked. Signal is wired in world.gd `_ready()`.
**When to use:** Any time a UI node needs to trigger world-level state change without referencing world directly.

```gdscript
# death-screen.gd — add at class top
signal play_again_requested

# death-screen.gd — in _on_submit(), after _populate_table()
var play_again_btn := Button.new()
play_again_btn.text = "Play Again"
play_again_btn.pressed.connect(func(): play_again_requested.emit())
$LeaderboardSection/VBox.add_child(play_again_btn)
```

```gdscript
# world.gd — in _ready(), after death_screen is instantiated and added
death_screen.play_again_requested.connect(_restart_game)
```

### Pattern 2: In-Place State Reset (No Scene Reload)
**What:** `_restart_game()` in world.gd does a sequential teardown and re-initialization.
**When to use:** Any time the game must restart without OS process restart.

```gdscript
# world.gd
func _restart_game() -> void:
    get_tree().paused = false
    death_screen.visible = false

    # Clear enemies
    for enemy in get_tree().get_nodes_in_group("enemy"):
        enemy.queue_free()

    # Clear items (no group — class filter)
    for child in get_children():
        if child is Item:
            child.queue_free()

    # Clear asteroids (no group — class filter)
    for child in get_children():
        if child is Asteroid:
            child.queue_free()

    # Reset player
    var ship := $ShipBFG23
    ship.global_position = Vector2.ZERO
    ship.linear_velocity = Vector2.ZERO
    ship.angular_velocity = 0.0
    ship.health = ship.max_health
    ship.dying = false

    # Reset subsystems
    ScoreManager.reset()
    $WaveManager.reset()
    MusicManager.reset()

    # Respawn world
    spawn_asteroids(100)
    _wave_clear_pending = false
    $WaveManager.trigger_wave()
```

### Pattern 3: WaveManager.reset()
**What:** Zero all wave-tracking state so trigger_wave() restarts from Wave 1.

```gdscript
# wave-manager.gd
func reset() -> void:
    _current_wave_index = 0
    _enemies_alive = 0
    _wave_total = 0
    print("[WaveManager] Reset to Wave 1")
```

### Pattern 4: ScoreManager.reset()
**What:** Zero score, kills, combo, multiplier. Stop combo timer.

```gdscript
# score-manager.gd
func reset() -> void:
    total_score = 0
    kill_count = 0
    wave_multiplier = 1
    combo_count = 0
    _combo_timer.stop()
    score_changed.emit(total_score, 0)
    multiplier_changed.emit(wave_multiplier)
    combo_updated.emit(0)
    print("[ScoreManager] Reset")
```

### Anti-Patterns to Avoid
- **Using `get_tree().reload_current_scene()`:** Explicitly forbidden. Causes MusicManager and ScoreManager autoloads to re-run `_ready()`, resetting all connections. Also triggers a scene unload/reload cycle.
- **Calling `trigger_wave()` before `WaveManager.reset()`:** If `_current_wave_index` is not zeroed first, the next wave spawned will be wave N+1, not Wave 1.
- **Clearing enemies with `queue_free()` inside a `for` loop over the group:** Safe in GDScript — `queue_free()` schedules deletion for end of frame; the loop completes normally. Do not call `free()` directly (immediate deallocation mid-loop).
- **Forgetting `ship.dying = false`:** `Body.dying` is set to `true` at the start of `die()` and never reset. If not cleared, any subsequent damage call is a no-op (`if dying: return`), making the ship unkillable next run.
- **Forgetting to emit reset signals from ScoreManager:** The ScoreHUD observes `score_changed` and `multiplier_changed`. Without emitting those signals in `reset()`, the HUD will display stale values from the last run.
- **Adding the Play Again button multiple times:** If the player dies twice without restarting, `_on_submit()` is guarded by `_submitted`, but the button append code could run again on next death if not checked. Use `_submitted` guard already in place — the button must be added only once per submit cycle.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Node group iteration | Manual child traversal | `get_tree().get_nodes_in_group("enemy")` | Already works; WaveManager already adds enemies to group |
| Cross-fade music reset | Custom stop/start logic | `MusicManager.reset()` | Already implemented in Phase 16; tested |
| Tween cleanup | Leaving tweens running | `tween.kill()` before reset | Active tweens referencing freed nodes cause errors |
| Leaderboard button wiring | Modifying the .tscn | Add button programmatically in `_on_submit()` | Button only needs to appear after submit; runtime creation is simpler and consistent with how rows are built |

**Key insight:** The hard parts (MusicManager.reset, enemy group tracking) are already built. This phase is primarily wiring.

---

## Common Pitfalls

### Pitfall 1: Body.dying Flag Not Reset
**What goes wrong:** Player dies again in a subsequent run but takes no damage — health appears to deplete in HUD but `die()` never fires.
**Why it happens:** `Body.die()` sets `dying = true` as a re-entrancy guard. It is never set back to `false` anywhere in the codebase. If `_restart_game()` restores `health` but not `dying`, the ship is immortal.
**How to avoid:** Explicitly set `$ShipBFG23.dying = false` in `_restart_game()` after restoring health.
**Warning signs:** Player survives hits that should be lethal; no `died` signal emits on second run.

### Pitfall 2: WaveManager Fires Wave 2 Instead of Wave 1
**What goes wrong:** First wave after restart has wave 2 enemies.
**Why it happens:** `_current_wave_index` is 1-based after first `trigger_wave()` call (it increments before spawning). If not reset to 0, the next `trigger_wave()` starts at index 1 (Wave 2).
**How to avoid:** Call `WaveManager.reset()` before `trigger_wave()` in `_restart_game()`.
**Warning signs:** "Wave 2: Beelines" appears immediately after restart.

### Pitfall 3: Tree Paused During Cleanup Causes queue_free() Silently Deferred
**What goes wrong:** Enemies or nodes are not fully freed before spawn_asteroids runs, causing overlap.
**Why it happens:** `get_tree().paused = true` was set on death. While paused, some deferred calls may not process normally.
**How to avoid:** Unpause (`get_tree().paused = false`) as the FIRST step in `_restart_game()`, before any `queue_free()` calls. This matches D-08 order.
**Warning signs:** Ghost enemies visible at start of new game.

### Pitfall 4: ScoreHUD Shows Stale Score
**What goes wrong:** HUD still shows previous run's score/multiplier at start of new game.
**Why it happens:** ScoreHUD listens to `score_changed` and `multiplier_changed` signals. If `reset()` doesn't emit these signals, the HUD never updates.
**How to avoid:** Emit `score_changed.emit(0, 0)`, `multiplier_changed.emit(1)`, and `combo_updated.emit(0)` inside `ScoreManager.reset()`.
**Warning signs:** HUD score doesn't go to 0 after restart.

### Pitfall 5: Active Combo Timer Fires After Reset
**What goes wrong:** After reset, `_on_combo_expired()` fires (from the timer running during the previous game) and tries to emit signals — harmless but noisy/confusing.
**Why it happens:** `_combo_timer` continues running in the background when the tree is paused (Timer's process_mode defaults to `WHEN_PAUSED = false`, so it should pause... but verify).
**How to avoid:** Call `_combo_timer.stop()` inside `ScoreManager.reset()` before zeroing `combo_count`.
**Warning signs:** Spurious `[ScoreManager] Combo x0 ends` print at game start.

### Pitfall 6: Items and Asteroids Have No Group
**What goes wrong:** `get_tree().get_nodes_in_group("asteroid")` returns empty.
**Why it happens:** Asteroids and items are never added to a named group — verified by reading `asteroid.gd` (`class_name Asteroid extends Body` — no `add_to_group`), `item.gd` (same), and `world.gd`'s `add_asteroid()` (no group call).
**How to avoid:** Use class-based iteration: `for child in get_children(): if child is Asteroid: child.queue_free()`. This is safe because `get_children()` returns the immediate children of world.gd, which is the `spawn_parent` for all dynamic objects.
**Warning signs:** Asteroids persist across restart; no error is raised.

### Pitfall 7: Bullets In-Flight at Death Time
**What goes wrong:** Bullets fired in the last moment before death linger in the world after restart.
**Why it happens:** Bullets are `RigidBody2D` nodes added to world as children; they self-destruct on collision but not on game-over.
**How to avoid:** Iterate `get_children()` for any node that is not a permanent child (ShipBFG23, WaveManager, cameras, HUD, DeathScreen, etc.). The safest approach: `queue_free()` all children that are `RigidBody2D` and not in the permanent-child set — or simply add all bullet scenes to a "bullet" group at instantiation time.
**Alternative:** Accept that a few bullets may linger for 1-2 frames post-restart (they will disappear when they hit asteroids). Given the phase scope, this may be acceptable.
**Warning signs:** Stray bullets visible at game start.

---

## Code Examples

### DeathScreen: Signal Declaration and Button Addition

```gdscript
# death-screen.gd — top of class
signal play_again_requested

# death-screen.gd — end of _on_submit(), after _populate_table(entries)
var play_again_btn := Button.new()
play_again_btn.text = "Play Again"
play_again_btn.add_theme_font_size_override("font_size", 22)
play_again_btn.pressed.connect(func(): play_again_requested.emit())
$LeaderboardSection/VBox.add_child(play_again_btn)
```

### world.gd: Signal Wiring in _ready()

```gdscript
# After: death_screen = death_screen_model.instantiate() / add_child(death_screen)
death_screen.play_again_requested.connect(_restart_game)
```

### world.gd: Full _restart_game()

```gdscript
func _restart_game() -> void:
    get_tree().paused = false
    death_screen.visible = false
    _wave_clear_pending = false

    for enemy in get_tree().get_nodes_in_group("enemy"):
        enemy.queue_free()

    for child in get_children():
        if child is Item:
            child.queue_free()

    for child in get_children():
        if child is Asteroid:
            child.queue_free()

    var ship := $ShipBFG23
    ship.global_position = Vector2.ZERO
    ship.linear_velocity = Vector2.ZERO
    ship.angular_velocity = 0.0
    ship.health = ship.max_health
    ship.dying = false

    ScoreManager.reset()
    $WaveManager.reset()
    MusicManager.reset()

    spawn_asteroids(100)
    $WaveManager.trigger_wave()
```

### wave-manager.gd: reset()

```gdscript
func reset() -> void:
    _current_wave_index = 0
    _enemies_alive = 0
    _wave_total = 0
    print("[WaveManager] Reset to Wave 1")
```

### score-manager.gd: reset()

```gdscript
func reset() -> void:
    total_score = 0
    kill_count = 0
    wave_multiplier = 1
    combo_count = 0
    _combo_timer.stop()
    score_changed.emit(total_score, 0)
    multiplier_changed.emit(wave_multiplier)
    combo_updated.emit(0)
    print("[ScoreManager] Reset")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `get_tree().reload_current_scene()` | In-place reset with explicit state zeroing | Godot 3 → 4 era | Avoids autoload re-init; preserves signal connections; faster UX |

**Deprecated/outdated:**
- `get_tree().reload_current_scene()` and `get_tree().change_scene_to_*()`: Both are explicitly forbidden per D-08. They break autoload signal connections and are unnecessary for this single-scene architecture.

---

## Runtime State Inventory

> This is not a rename/refactor phase. Skipped.

---

## Environment Availability

> This phase is purely GDScript code changes within an existing Godot project. No external tools, CLIs, databases, or services are required beyond the Godot editor already confirmed present.

Step 2.6: SKIPPED (no external dependencies — all changes are in-engine GDScript).

---

## Open Questions

1. **Bullets lingering after restart**
   - What we know: Bullets are instantiated as children of world.gd (via `spawn_parent`). They self-destruct on collision. No group tag is added at spawn time.
   - What's unclear: Phase scope says to ignore this or address it. Given bullets are transient (< 2 second lifetime), they will self-clear even if not explicitly freed.
   - Recommendation: Accept the edge case for this phase. Planner should note it as a known limitation with no action required unless the user surfaces it as a bug.

2. **WaveHud state on restart**
   - What we know: `_wave_hud` displays wave announcements and a "wave cleared" label. It's wired to WaveManager signals in `_ready()`.
   - What's unclear: Does `_wave_hud.hide_wave_clear_label()` need to be called in `_restart_game()` to prevent stale label from previous run?
   - Recommendation: Yes, call `_wave_hud.hide_wave_clear_label()` in `_restart_game()` for safety. Already done for `_on_player_died()`, so mirror the pattern.

---

## Validation Architecture

> `nyquist_validation` is `false` in config.json — this section is omitted per config.

---

## Security Domain

> This phase adds no network calls, file I/O beyond the existing ConfigFile leaderboard, or user input processing beyond a button press. No new ASVS surface area introduced. Security domain skipped.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Bullets self-destruct within 2 seconds and do not require explicit cleanup | Common Pitfalls / Open Questions | Minor visual artifact (stray bullets) at game start; no gameplay impact |
| A2 | `get_children()` on world.gd returns all dynamically-spawned nodes (enemies, asteroids, items) because world.gd is the `spawn_parent` for all of them | Architecture Patterns | If some nodes are parented elsewhere, cleanup loop will miss them |

All other claims were verified by reading actual source files in this session.

---

## Sources

### Primary (HIGH confidence — verified by reading source files)
- `world.gd` — `_on_player_died()`, `spawn_asteroids()`, `_ready()`, `_wave_clear_pending` usage
- `prefabs/ui/death-screen.gd` — `_on_submit()`, `_submitted` guard, `_leaderboard_section` reference, signal wiring in `_ready()`
- `prefabs/ui/death-screen.tscn` — LeaderboardSection/VBox node path confirmed; no PlayAgain button exists yet
- `components/wave-manager.gd` — `_current_wave_index`, `_enemies_alive`, `_wave_total` confirmed; `trigger_wave()` increments index before spawning; no `reset()` method exists
- `components/score-manager.gd` — `total_score`, `kill_count`, `wave_multiplier`, `combo_count`, `_combo_timer` confirmed; no `reset()` method exists
- `components/music-manager.gd` — `reset()` method exists and is complete (Phase 16)
- `components/body.gd` — `dying` flag, `max_health`, `health` fields confirmed; `die()` guard confirmed
- `components/asteroid.gd` — No group registration; class-based cleanup required
- `components/item.gd` — No group registration; class-based cleanup required
- `.planning/phases/17-game-restart/17-CONTEXT.md` — All decisions D-01 through D-11

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — Architecture constraints re: MusicManager as autoload, restart sequence order

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Godot built-ins, verified in codebase
- Architecture: HIGH — All patterns derived from actual source code, not assumptions
- Pitfalls: HIGH — `Body.dying` flag, group absence, timer behavior verified in source

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable Godot 4 patterns; no fast-moving ecosystem)
