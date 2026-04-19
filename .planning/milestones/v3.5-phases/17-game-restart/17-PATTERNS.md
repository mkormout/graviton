# Phase 17: Game Restart - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 4 modified files
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `prefabs/ui/death-screen.gd` | component (UI) | event-driven | `prefabs/ui/death-screen.gd` itself (extends existing file) | self |
| `world.gd` | orchestrator | event-driven + CRUD | `world.gd` itself (extends existing file) | self |
| `components/wave-manager.gd` | service / state manager | event-driven | `components/score-manager.gd` | role-match (both are stateful Node managers with signal wiring) |
| `components/score-manager.gd` | service / state manager | event-driven | `components/wave-manager.gd` | role-match |

---

## Pattern Assignments

### `prefabs/ui/death-screen.gd` (component, event-driven)

**Change:** Add `play_again_requested` signal; append "Play Again" button to `_leaderboard_section` inside `_on_submit()` after `_populate_table()`.

**Analog:** `prefabs/ui/death-screen.gd` (self — extend, do not replace)

**Existing class declaration** (lines 1–2):
```gdscript
class_name DeathScreen
extends CanvasLayer
```

**Existing signal wiring pattern** (lines 22–25 — how `_ready()` connects UI signals):
```gdscript
func _ready() -> void:
    _name_input.text_submitted.connect(_on_submit)
    _submit_button.pressed.connect(_on_submit.bind(""))
    visible = false
```

**Existing guard pattern** (lines 43–46 — `_submitted` prevents double-run):
```gdscript
func _on_submit(_text: String = "") -> void:
    if _submitted:
        return
    _submitted = true
```

**Existing dynamic node creation pattern** (lines 128–157 — `_add_row()` shows how buttons/labels are built and added at runtime):
```gdscript
var row := HBoxContainer.new()
var rank_label := Label.new()
rank_label.add_theme_font_size_override("font_size", 18)
rank_label.add_theme_color_override("font_color", color)
rank_label.add_theme_color_override("font_outline_color", Color.BLACK)
rank_label.add_theme_constant_override("outline_size", 3)
row.add_child(rank_label)
_rows_container.add_child(row)
```

**New signal declaration — insert after line 2 (class declaration block):**
```gdscript
signal play_again_requested
```

**New button addition — insert at end of `_on_submit()`, after `_populate_table(entries)` (after line 66):**
```gdscript
var play_again_btn := Button.new()
play_again_btn.text = "Play Again"
play_again_btn.add_theme_font_size_override("font_size", 22)
play_again_btn.pressed.connect(func(): play_again_requested.emit())
_leaderboard_section.get_node("VBox").add_child(play_again_btn)
```

**Key constraint:** The button must be added inside the `_submitted` guard so it is added only once per submit cycle. The `_submitted = true` check on lines 44–46 already prevents re-entry.

---

### `world.gd` (orchestrator, event-driven + CRUD)

**Change:** Wire `death_screen.play_again_requested` signal in `_ready()`; implement `_restart_game()` method.

**Analog:** `world.gd` (self — extend, do not replace)

**Existing signal wiring pattern in `_ready()`** (lines 79–81 — how world.gd connects to other nodes' signals):
```gdscript
death_screen = death_screen_model.instantiate()
add_child(death_screen)
$ShipBFG23.died.connect(_on_player_died)
```
Copy this pattern: `death_screen.play_again_requested.connect(_restart_game)` immediately after the existing death_screen block.

**Existing cleanup / state reset pattern** (lines 395–399 — `_on_player_died()` is the inverse of `_restart_game()`):
```gdscript
func _on_player_died() -> void:
    _wave_clear_pending = false
    _wave_hud.hide_wave_clear_label()
    get_tree().paused = true
    death_screen.show_death_screen(ScoreManager.total_score)
```

**Existing spawn_asteroids call** (lines 351–359 — signature and usage to re-call on restart):
```gdscript
func spawn_asteroids(count: int):
    for x in range(count * 0.5):
        add_asteroid(asteroids_small_model.pick_random())
    for x in range(count * 0.4):
        add_asteroid(asteroids_medium_model.pick_random())
    for x in range(count * 0.1):
        add_asteroid(asteroids_large_model.pick_random())
```

**Existing wave trigger pattern** (lines 300–304 — how trigger_wave is called after clearing pending state):
```gdscript
if _wave_clear_pending:
    _wave_clear_pending = false
    $WaveManager.trigger_wave()
    _wave_hud.hide_wave_clear_label()
```

**New `_restart_game()` method — add after `_on_player_died()` (after line 399):**
```gdscript
func _restart_game() -> void:
    get_tree().paused = false
    death_screen.visible = false
    _wave_clear_pending = false
    _wave_hud.hide_wave_clear_label()

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

**Reset order rationale (from D-08):** Unpause first so `queue_free()` processes normally. Reset all subsystems before spawning so Wave 1 launches with clean state.

---

### `components/wave-manager.gd` (service, event-driven)

**Change:** Add `reset()` method that zeroes `_current_wave_index`, `_enemies_alive`, and `_wave_total`.

**Analog:** `components/score-manager.gd` — closest existing example of a stateful Node manager that will also receive a `reset()`. Both share the same pattern: private state vars set in `_ready()` equivalent, manipulated by signal handlers.

**Existing private state declarations** (lines 17–20 — vars that `reset()` must zero):
```gdscript
var _current_wave_index: int = 0
var _enemies_alive: int = 0
var _wave_total: int = 0
var _player: Node2D = null
```

**Existing debug print pattern** (lines 67, 128 — format used throughout WaveManager):
```gdscript
print("[WaveManager] Starting wave %d: %d enemies — %s" % [_current_wave_index, total_count, label_text])
print("[WaveManager] Wave %d complete!" % (_current_wave_index))
```

**New `reset()` method — add after `_on_wave_complete()` (after line 133):**
```gdscript
func reset() -> void:
    _current_wave_index = 0
    _enemies_alive = 0
    _wave_total = 0
    print("[WaveManager] Reset to Wave 1")
```

**Critical constraint:** `reset()` must NOT call `trigger_wave()`. world.gd calls `trigger_wave()` manually after `reset()` (same pattern as `_ready()` in world.gd does not auto-trigger — see world.gd lines 88–89 where `spawn_asteroids` is called but `trigger_wave` is not in `_ready()`).

---

### `components/score-manager.gd` (service, event-driven)

**Change:** Add `reset()` method that zeroes `total_score`, `kill_count`, `combo_count`, resets `wave_multiplier` to 1, stops `_combo_timer`, and emits reset signals to HUD.

**Analog:** `components/music-manager.gd` — the only existing manager that already has a `reset()` method (added in Phase 16). Use it as the canonical reference for reset method structure.

**MusicManager.reset() structure to mirror** (`components/music-manager.gd` lines 122–136):
```gdscript
func reset() -> void:
    if _active_tween and _active_tween.is_running():
        _active_tween.kill()
        _active_tween = null
    _current_category = "ambient"
    _last_track = null
    _player_a.stop()
    _player_b.stop()
    _player_b.volume_db = -80.0
    _player_a.volume_db = music_volume_db
    var track := _pick_track("ambient")
    if track:
        _player_a.stream = track
        _player_a.play()
    print("[MusicManager] Reset to ambient")
```

Pattern: zero/restore all state vars → stop any async processes → emit signals to notify observers → print confirmation.

**Existing state vars to reset** (`components/score-manager.gd` lines 15–18):
```gdscript
var total_score: int = 0
var kill_count: int = 0
var wave_multiplier: int = 1
var combo_count: int = 0
```

**Existing signals to emit on reset** (lines 4–7 — HUD observes these; must be emitted to flush stale display values):
```gdscript
signal score_changed(new_score: int, delta: int)
signal multiplier_changed(new_multiplier: int)
signal combo_updated(combo_count: int)
signal combo_expired()
```

**Existing timer usage pattern** (lines 92–98 — how `_combo_timer.start()` is used; `stop()` is the inverse):
```gdscript
func _increment_combo() -> void:
    combo_count += 1
    _combo_timer.start()
```

**New `reset()` method — add after `_on_player_health_changed()` (after line 181):**
```gdscript
func reset() -> void:
    _combo_timer.stop()
    total_score = 0
    kill_count = 0
    wave_multiplier = 1
    combo_count = 0
    score_changed.emit(total_score, 0)
    multiplier_changed.emit(wave_multiplier)
    combo_updated.emit(0)
    print("[ScoreManager] Reset")
```

**Why stop timer first:** Stops any in-flight combo timeout before zeroing `combo_count`, preventing a spurious `_on_combo_expired()` callback from firing after reset with stale combo values.

---

## Shared Patterns

### Signal Declaration Convention
**Source:** `components/wave-manager.gd` lines 4–9, `components/score-manager.gd` lines 4–7
**Apply to:** `prefabs/ui/death-screen.gd` (new `play_again_requested` signal)
```gdscript
signal play_again_requested
```
Signals are declared at class scope, before `@export` vars, no type annotation required for zero-argument signals.

### Signal Connection in `_ready()`
**Source:** `world.gd` lines 79–81; `prefabs/ui/death-screen.gd` lines 23–24
**Apply to:** `world.gd` (connecting `play_again_requested`)
```gdscript
# Pattern: connect immediately after add_child on the emitting node
death_screen = death_screen_model.instantiate()
add_child(death_screen)
$ShipBFG23.died.connect(_on_player_died)
# NEW: add here:
death_screen.play_again_requested.connect(_restart_game)
```

### Debug Print Format
**Source:** Throughout `world.gd`, `wave-manager.gd`, `score-manager.gd`, `music-manager.gd`
**Apply to:** All new methods
```gdscript
print("[ClassName] Description")
# Examples:
print("[WaveManager] Reset to Wave 1")
print("[ScoreManager] Reset")
print("[MusicManager] Reset to ambient")
```

### Node Group Iteration for Cleanup
**Source:** `components/wave-manager.gd` line 94 (`enemy.add_to_group("enemy")`) and Godot built-in
**Apply to:** `world.gd._restart_game()` (enemy cleanup only)
```gdscript
for enemy in get_tree().get_nodes_in_group("enemy"):
    enemy.queue_free()
```
Items and asteroids have no group — use class-based iteration instead (see Pattern Assignments above).

### Tween Kill Before Reset
**Source:** `components/music-manager.gd` lines 123–126
**Apply to:** Any reset that touches state shared with active Tweens
```gdscript
if _active_tween and _active_tween.is_running():
    _active_tween.kill()
    _active_tween = null
```
ScoreManager's floating score labels use Tweens on `Node2D` instances parented to `current_scene`. Those nodes are queue_freed when the parent world node is cleaned up — the `_restart_game()` cleanup loop handles them via the `get_children()` iteration. No explicit tween kill needed in ScoreManager.reset() for those; only the combo timer requires a stop.

---

## No Analog Found

No files in this phase lack an analog. All four modified files exist in the codebase and serve as their own analog for extension-style changes.

---

## Metadata

**Analog search scope:** `prefabs/ui/`, `components/`, `world.gd`
**Files read:** 5 (`death-screen.gd`, `world.gd`, `wave-manager.gd`, `score-manager.gd`, `music-manager.gd`)
**Pattern extraction date:** 2026-04-18
