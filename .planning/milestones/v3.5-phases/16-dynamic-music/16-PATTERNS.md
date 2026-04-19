# Phase 16: Dynamic Music - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 3 (1 new, 2 modified)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `components/music-manager.gd` | service (autoload) | event-driven | `components/score-manager.gd` | exact |
| `world.gd` | config/wiring | request-response | `world.gd` lines 65-67 (ScoreManager wiring) | exact (self-reference) |
| `project.godot` | config | — | `project.godot` lines 19-21 ([autoload] section) | exact (self-reference) |

---

## Pattern Assignments

### `components/music-manager.gd` (service/autoload, event-driven)

**Analog:** `components/score-manager.gd`

**Imports / class declaration pattern** (score-manager.gd lines 1-4):
```gdscript
extends Node

## Signals for Phase 12 HUD consumption
signal score_changed(new_score: int, delta: int)
```
MusicManager mirrors this: `extends Node`, optional signal for category_changed, no `class_name` needed (autoloads are accessed by name globally).

**Child node creation in _ready() pattern** (score-manager.gd lines 26-40):
```gdscript
func _ready() -> void:
    # Combo timer — one-shot, 5 second timeout
    _combo_timer = Timer.new()
    _combo_timer.wait_time = COMBO_TIMEOUT
    _combo_timer.one_shot = true
    _combo_timer.timeout.connect(_on_combo_expired)
    add_child(_combo_timer)

    # Combo audio — non-positional AudioStreamPlayer
    _combo_audio = AudioStreamPlayer.new()
    _combo_audio.stream = preload("res://sounds/combo.wav")
    add_child(_combo_audio)

    # Deferred player lookup — autoloads run before scene nodes are ready
    call_deferred("_find_player")
```
MusicManager copies this exactly: create `AudioStreamPlayer` (not 2D) nodes in `_ready()`, `add_child()` them, then `call_deferred("_start_playback")` instead of `_find_player`.

**connect_to_wave_manager entry point pattern** (score-manager.gd lines 53-56):
```gdscript
## Called by world.gd to wire WaveManager signals
func connect_to_wave_manager(wm: Node) -> void:
    wm.wave_completed.connect(_on_wave_completed)
    print("[ScoreManager] Connected to WaveManager wave_completed signal")
```
MusicManager implements the same function signature but connects to `wm.wave_started` (not `wave_completed`):
```gdscript
func connect_to_wave_manager(wm: Node) -> void:
    wm.wave_started.connect(_on_wave_started)
    print("[MusicManager] Connected to WaveManager wave_started signal")
```

**WaveManager signal signature** (wave-manager.gd line 4):
```gdscript
signal wave_started(wave_number: int, enemy_count: int, label_text: String)
```
Handler must accept all three parameters: `func _on_wave_started(wave_number: int, _enemy_count: int, _label_text: String) -> void`.

**Tween with set_parallel — parallel property animation** (score-manager.gd lines 160-164):
```gdscript
var tween := node.create_tween()
tween.set_parallel(true)
tween.tween_property(node, "global_position:y", world_pos.y - 120.0, 1.5)
tween.tween_property(label, "modulate:a", 0.0, 1.5)
tween.chain().tween_callback(node.queue_free)
```
MusicManager cross-fade uses the same `set_parallel(true)` + `chain().tween_callback()` structure. The only difference: two `volume_db` properties are tweened instead of position and alpha.

**Tween for PointLight2D pulse — infinite looping tween** (components/beeliner.gd lines 132-137):
```gdscript
func _start_pulse(light: PointLight2D) -> void:
    var tween := create_tween()
    tween.set_loops(0)  # 0 = infinite in Godot 4
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(light, "energy", gem_energy_max, gem_pulse_half_period)
    tween.tween_property(light, "energy", gem_energy_min, gem_pulse_half_period)
```
Cross-fade does NOT loop. But this confirms `tween_property(node, "property_name", target_value, duration)` signature is correct and used in production.

**AudioStreamPlayer (non-positional) pattern** (score-manager.gd lines 34-37 and random-audio-player.gd lines 8-15):
```gdscript
# score-manager.gd — non-positional (correct for background music)
_combo_audio = AudioStreamPlayer.new()
_combo_audio.stream = preload("res://sounds/combo.wav")
add_child(_combo_audio)

# random-audio-player.gd — positional 2D variant (DO NOT use for music)
audio = AudioStreamPlayer2D.new()
audio.max_distance = 30000
audio.volume_db = volume_db
add_child(audio)
```
MusicManager uses `AudioStreamPlayer` (non-positional), not `AudioStreamPlayer2D`. `volume_db` property is the same on both.

**pick_random() usage** (random-audio-player.gd line 24):
```gdscript
audio.stream = resources.pick_random()
```
MusicManager's `_pick_track()` uses `candidates.pick_random()` — same Array method, confirmed available in this project.

**@export for tunable values** (wave-manager.gd lines 14-15):
```gdscript
@export var waves: Array = []
@export var spawn_radius_margin: float = 1000.0
```
MusicManager should expose `@export var crossfade_duration: float = 2.0` and wave threshold constants as `@export` vars so they can be tweaked in the editor (confirmed by CONTEXT.md code_context section).

---

### `world.gd` modification (wiring, request-response)

**Analog:** `world.gd` lines 65-67 — existing ScoreManager wiring block

**Exact pattern to mirror** (world.gd lines 65-67):
```gdscript
# Wire ScoreManager to WaveManager for wave multiplier (Phase 11)
if ScoreManager:
    ScoreManager.connect_to_wave_manager($WaveManager)
```
Add the MusicManager line immediately after, following the same guard pattern:
```gdscript
if MusicManager:
    MusicManager.connect_to_wave_manager($WaveManager)
```
Location: inside `_ready()`, after the existing ScoreManager block (world.gd line 67). No other world.gd changes needed.

---

### `project.godot` modification (config)

**Analog:** `project.godot` line 21 — existing ScoreManager autoload registration

**Exact pattern to mirror** (project.godot lines 19-21):
```gdscript
[autoload]

ScoreManager="*res://components/score-manager.gd"
```
Add one line after `ScoreManager`:
```
MusicManager="*res://components/music-manager.gd"
```
The `*` prefix is Godot's syntax for autoloads that are script-only (no scene file). Must match the ScoreManager format exactly.

---

## Shared Patterns

### Autoload Node Construction
**Source:** `components/score-manager.gd` lines 26-40
**Apply to:** `components/music-manager.gd`

All children (AudioStreamPlayers) are created programmatically in `_ready()` via `Node.new()` + `add_child()`. No scene file (.tscn) required. Autoload scripts are registered directly in `project.godot [autoload]` with the `*` prefix.

### Deferred Wiring to Scene Nodes
**Source:** `components/score-manager.gd` line 40 and lines 53-56
**Apply to:** `components/music-manager.gd`

Autoloads must never access scene nodes in `_ready()` directly. Pattern: use `call_deferred("_some_method")` for any initialization that needs scene nodes, OR expose a `connect_to_X(node)` method that `world.gd` calls from its own `_ready()` (after scene tree is populated).

MusicManager uses both: `call_deferred("_start_playback")` for initial playback, and `connect_to_wave_manager(wm)` for signal wiring.

### print() Debug Logging
**Source:** `components/score-manager.gd` lines 50, 56, 83, 100, etc.
**Apply to:** `components/music-manager.gd`

All significant state transitions log via `print("[ClassName] message")` with bracketed class prefix. Matches project-wide convention (visible in score-manager.gd, wave-manager.gd).

### Tween parallel + chain + callback
**Source:** `components/score-manager.gd` lines 160-164
**Apply to:** `components/music-manager.gd` cross-fade function

```gdscript
var tween := node.create_tween()
tween.set_parallel(true)
tween.tween_property(...)  # property A
tween.tween_property(...)  # property B
tween.chain().tween_callback(some_callback)
```
This is the project-verified pattern. `chain()` ensures the callback fires after all parallel tweens complete.

---

## No Analog Found

All three files have direct analogs. No files require falling back to RESEARCH.md patterns exclusively.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | — |

---

## Critical Implementation Notes for Planner

1. **Wave 0 prerequisite (blocking):** Three MP3 files (`Gravity-Drum Choir.mp3`, `Static Lullaby.mp3`, `Sulfur Orbit.mp3`) have no `.import` files yet. Confirmed by `ls music/` — only `Gravimetric Dawn.mp3.import` exists. Plan must open Godot editor first and verify all 4 `.import` files before any GDScript references them.

2. **`var` not `const` for catalog:** Use `var _catalog: Dictionary` initialized at class scope with `preload()` calls, not `const`. See RESEARCH.md Pitfall 5.

3. **loop=true required:** `Gravimetric Dawn.mp3.import` has `loop=false` (confirmed in RESEARCH.md). Must be changed to `loop=true` for all four tracks in the editor Import tab as part of Wave 0.

4. **Store active Tween reference:** `var _active_tween: Tween = null`. Kill it at the top of every `_crossfade()` call to prevent volume corruption on rapid category changes (RESEARCH.md Pitfall 3).

5. **`wave_started` not `wave_completed`:** ScoreManager connects to `wave_completed`. MusicManager must connect to `wave_started` — music shifts as enemies arrive, not after they're all killed (D-02).

---

## Metadata

**Analog search scope:** `components/`, `world.gd`, `project.godot`
**Files scanned:** 5 (`score-manager.gd`, `wave-manager.gd`, `world.gd`, `random-audio-player.gd`, `beeliner.gd`)
**Pattern extraction date:** 2026-04-17
