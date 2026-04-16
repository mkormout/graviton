# Phase 11: ScoreManager - Research

**Researched:** 2026-04-14
**Domain:** GDScript autoload singleton, signal-driven event tracking, combo timer, audio pitch scaling
**Confidence:** HIGH

## Summary

Phase 11 creates a self-contained ScoreManager autoload that tracks kills, wave multipliers, and combo chains entirely in GDScript with no external dependencies. All design decisions are locked in CONTEXT.md; this research surfaces implementation-critical details discovered by reading the live codebase directly.

The key findings are: (1) `combo.wav` exists in `sounds/` but has **no `.import` file** — the editor must reimport it before it can be loaded at runtime; (2) WaveManager has no per-wave-completion signal today (`_on_wave_complete()` is private, no public signal emitted) so one must be added; (3) `Body.die()` calls `queue_free()` but does not emit any signal — the `died` signal must be added before `queue_free()`; (4) the `health_changed` signal in `Body.damage()` requires saving `old_health` before `health += total` since the line mutates in place.

**Primary recommendation:** Build exactly as specified in CONTEXT.md. No library needed — Godot's built-in Timer node, AudioStreamPlayer, and signal system are sufficient and are already the established project patterns.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: ScoreManager is an autoload singleton registered in `project.godot`
- D-02: `died` signal added to `Body.gd`, fired inside `die()`
- D-03: `health_changed(old_health: int, new_health: int)` signal added to `Body.gd`, fired inside `damage()` when health decreases
- D-04: `@export var score_value: int = 100` added to `EnemyShip` base class
- D-05: Point values — Beeliner=100, Swarmer=50, Flanker=150, Sniper=200, Suicider=75
- D-06: Wave multiplier: ×1→×2→×4→×8→×16 cap, doubles per wave completed without damage
- D-07: Reset to ×1 on any player damage (via `health_changed` signal)
- D-08: ScoreManager listens to WaveManager signals for multiplier advancement
- D-09: Combo starts at 0; second kill within 5 s = combo of 2; extends per kill
- D-10: Combo expires after 5 s of no kills; awards combo bonus on expiry
- D-11: Combo bonus = `combo_count × 25 × wave_multiplier`
- D-12: Combo sound file: `sounds/combo.wav`
- D-13: Pitch progression: semitone steps — `pitch_scale = pow(1.0595, combo_count - 1)`; combo kill 2 = 1.0, kill 3 = 1.0595, kill 4 = 1.12
- D-14: Non-positional `AudioStreamPlayer` on ScoreManager node itself

### Claude's Discretion
- Exact ScoreManager signal names for Phase 12 HUD (e.g., `score_changed`, `multiplier_changed`, `combo_updated`)
- Whether combo timer uses a Godot `Timer` node or `_process` delta accumulation
- Whether wave multiplier advancement hooks via `WaveManager.wave_started` or a new signal
- Exact combo bonus formula fine-tuning within the spirit of D-11

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GDScript | Godot 4.6 built-in | All game logic | Project constraint — no other languages |
| Godot Autoload | Engine feature | Global singleton registration | Standard Godot pattern for game-wide state |
| Godot Timer node | Engine node | Combo expiry countdown | Established pattern in this codebase (WaveManager, MountableWeapon) |
| AudioStreamPlayer | Engine node | Non-positional audio | Correct for UI feedback audio — non-spatial |
| Godot Signals | Engine feature | Kill/damage/wave event propagation | Primary event mechanism throughout codebase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AudioStreamWAV | Engine resource | WAV audio stream loaded by AudioStreamPlayer | combo.wav is WAV format, already present |
| `get_tree().get_first_node_in_group("player")` | Engine API | Player node lookup in autoload `_ready()` | Established pattern — WaveManager uses same lookup |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Timer node for combo | `_process` delta accumulation | Timer node is cleaner, matches WaveManager/MountableWeapon patterns; delta accumulation would require `_process` overhead even when no combo is active |
| `get_first_node_in_group` in ScoreManager._ready | Direct node path via `$` | Autoload cannot reference scene nodes via `$`; group lookup is the only viable approach |

**Installation:** No installation needed. Pure GDScript + engine built-ins.

**Version verification:** Godot 4.6 confirmed via `project.godot` line: `config/features=PackedStringArray("4.6", "GL Compatibility")` [VERIFIED: codebase read]

## Architecture Patterns

### Recommended Project Structure
```
components/
├── body.gd               # ADD: died signal, health_changed signal
├── enemy-ship.gd         # ADD: @export var score_value: int = 100
├── wave-manager.gd       # ADD: wave_completed(wave_number: int) signal
└── score-manager.gd      # NEW: autoload singleton
sounds/
└── combo.wav             # EXISTS — needs .import file generated by editor
project.godot             # ADD: [autoload] section with ScoreManager
```

### Pattern 1: Autoload Singleton Registration (Godot 4)
**What:** Global singleton declared in `project.godot` under `[autoload]`
**When to use:** Any game-wide state (score, audio bus, settings)
**Example:**
```gdscript
# project.godot — add this section (no existing [autoload] section today)
[autoload]

ScoreManager="*res://components/score-manager.gd"
```
The `*` prefix means "load as Node (not Resource)". [ASSUMED: standard Godot 4 autoload syntax — consistent with Godot docs pattern]

### Pattern 2: Typed Signal Declaration (WaveManager pattern)
**What:** Signals with typed parameters declared at top of class
**When to use:** All signals in this project
**Example:**
```gdscript
# Source: components/wave-manager.gd (verified by codebase read)
signal wave_started(wave_number: int, enemy_count: int, label_text: String)
signal enemy_count_changed(remaining: int, total: int)
signal all_waves_complete()
signal countdown_tick(seconds_remaining: int)
```
ScoreManager signals should follow same style:
```gdscript
signal score_changed(new_score: int, delta: int)
signal multiplier_changed(new_multiplier: int)
signal combo_updated(combo_count: int)
signal combo_expired(bonus_awarded: int)
```

### Pattern 3: Timer Node Programmatically Created (MountableWeapon pattern)
**What:** Timer created in `_ready()` with `Timer.new()`, connected, added as child
**When to use:** Any time-bounded event; established project pattern
**Example:**
```gdscript
# Source: components/mountable-weapon.gd (verified by codebase read)
var reload_timer: Timer
var shot_timer: Timer

func _ready() -> void:
    shot_timer = Timer.new()
    shot_timer.wait_time = rate
    shot_timer.one_shot = true
    add_child(shot_timer)
```
Combo timer for ScoreManager follows same pattern:
```gdscript
var _combo_timer: Timer

func _ready() -> void:
    _combo_timer = Timer.new()
    _combo_timer.wait_time = 5.0
    _combo_timer.one_shot = true
    _combo_timer.timeout.connect(_on_combo_expired)
    add_child(_combo_timer)
```

### Pattern 4: Group-Based Player Lookup (WaveManager pattern)
**What:** Find player node by group rather than hardcoded path
**When to use:** Autoloads and components that cannot reference scene nodes via `$`
**Example:**
```gdscript
# Source: components/wave-manager.gd (verified by codebase read)
func _find_player() -> void:
    _player = get_tree().get_first_node_in_group("player")
    if not _player:
        push_warning("[WaveManager] No node in group 'player' found")
```
ScoreManager uses identical approach. Player is added to group "player" in `world.gd:48`.

### Pattern 5: died Signal in Body.die() — Correct Insertion Point
**What:** Emit signal before `queue_free()` so receivers still have a valid reference
**When to use:** Any signal emitted at death
**Example:**
```gdscript
# Current body.gd die() — ADD died.emit() before queue_free()
func die(delay: float = 0.0):
    if dying:
        return
    # ... existing logic ...
    if item_dropper:
        item_dropper.drop()
    died.emit()    # <-- ADD before queue_free
    queue_free()
```
WaveManager currently uses `tree_exiting` to detect enemy death (connected before `add_child`). The new `died` signal is an alternative, cleaner approach that ScoreManager will use.

### Pattern 6: health_changed Signal — Save old_health First
**What:** Capture health before mutation to emit correct old/new values
**When to use:** Any before/after state signal
**Example:**
```gdscript
# Current body.gd damage() — save old_health BEFORE += total
func damage(attack: Damage):
    if not can_die or not attack:
        return
    var total = attack.calculate(defense)
    var old_health := health         # <-- SAVE before mutation
    health += total
    if old_health != health:
        health_changed.emit(old_health, health)   # <-- emit only if changed
    if health <= 0:
        die()
```

### Pattern 7: WaveManager wave_completed Signal Addition
**What:** Add public signal to `_on_wave_complete()` — currently private with no outgoing signal
**When to use:** ScoreManager needs to advance multiplier per wave
**Example:**
```gdscript
# wave-manager.gd — add to signal declarations
signal wave_completed(wave_number: int)

# wave-manager.gd _on_wave_complete() — add emit
func _on_wave_complete() -> void:
    print("[WaveManager] Wave %d complete!" % (_current_wave_index))
    wave_completed.emit(_current_wave_index)   # <-- ADD
    if _current_wave_index >= waves.size():
        all_waves_complete.emit()
    else:
        # ... countdown logic unchanged ...
```

### Pattern 8: AudioStreamPlayer for Non-Positional Audio
**What:** `AudioStreamPlayer` (not `AudioStreamPlayer2D`) for UI/feedback sounds
**When to use:** Sound should play at fixed volume regardless of screen position (combo feedback is UI feedback)
**Example:**
```gdscript
var _combo_audio: AudioStreamPlayer

func _ready() -> void:
    _combo_audio = AudioStreamPlayer.new()
    _combo_audio.stream = preload("res://sounds/combo.wav")
    add_child(_combo_audio)

func _play_combo_sound(combo_count: int) -> void:
    _combo_audio.pitch_scale = pow(1.0595, combo_count - 1)
    _combo_audio.play()
```
`pitch_scale` on AudioStreamPlayer is the correct property for pitch modification. [ASSUMED: Godot 4 AudioStreamPlayer API — consistent with training knowledge; requires combo.wav import file to be present]

### Anti-Patterns to Avoid
- **Connecting to enemy `tree_exiting` in ScoreManager:** WaveManager already uses this. Use the new `died` signal instead — it fires at the same time, before `queue_free`, and is semantically clearer.
- **Using `AudioStreamPlayer2D` for combo audio:** This is positional — volume falls off with distance. Non-positional `AudioStreamPlayer` is correct for UI feedback.
- **Emitting health_changed for positive health (healing):** D-07 says reset on damage. Only emit or respond when health decreases (`new_health < old_health`).
- **Autoload using `$ShipBFG23` or hardcoded scene paths:** Autoloads cannot access scene tree nodes by path until `_ready()` runs; use group lookup with `call_deferred("_find_player")` to match WaveManager's deferred approach.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Combo countdown | Custom delta accumulator in `_process` | Godot `Timer` node | Timer fires reliably, pauses with game, matches existing patterns |
| Audio pitch control | Manual frequency manipulation | `AudioStreamPlayer.pitch_scale` | Built-in engine property; semitone formula `pow(1.0595, n)` is a constant multiplier |
| Singleton pattern | Static var / global script workaround | Godot Autoload | Autoload is the Godot-native singleton mechanism; cleanest integration with scene tree |
| Wave completion tracking | Mirror WaveManager internal state | Listen to `wave_completed` signal | Don't duplicate WaveManager's counter — add the missing signal and consume it |

**Key insight:** All recurring patterns (Timer, group lookup, signal connections in `_ready`) are already established in WaveManager and MountableWeapon. ScoreManager should mirror those patterns exactly.

## Common Pitfalls

### Pitfall 1: combo.wav Has No .import File
**What goes wrong:** `preload("res://sounds/combo.wav")` fails at runtime or returns null; audio never plays; no obvious error in non-editor builds.
**Why it happens:** The file `sounds/combo.wav` was added to git but never opened in the Godot editor — the editor generates `.import` files automatically on first open, but `combo.wav.import` is absent from the directory.
**How to avoid:** Open the project in the Godot editor and let it reimport all assets before implementing ScoreManager audio. Alternatively, create the `.import` file manually by copying the pattern from `sounds/coin-pick.wav.import` with updated UIDs. Wave 0 task should ensure the import file exists.
**Warning signs:** Missing `sounds/combo.wav.import` file — confirmed absent by directory listing. [VERIFIED: codebase read]

### Pitfall 2: Emitting died After queue_free
**What goes wrong:** Signal fires but the Body node is already freed; connected receivers get a null or invalid reference; engine may crash or silently drop the signal.
**Why it happens:** `queue_free()` schedules removal but the node is gone by next frame.
**How to avoid:** Always emit `died` before calling `queue_free()` — already noted in Pattern 5. Order: `item_dropper.drop()` → `died.emit()` → `queue_free()`.
**Warning signs:** Sporadic null-reference errors in ScoreManager signal handlers.

### Pitfall 3: Wave Multiplier Fires Twice on all_waves_complete
**What goes wrong:** When the last wave finishes, `_on_wave_complete()` in WaveManager calls both `wave_completed.emit()` and `all_waves_complete.emit()`. If ScoreManager connects to both and advances the multiplier on both, the last wave would advance multiplier twice.
**Why it happens:** `all_waves_complete` fires from within `_on_wave_complete` — they are not mutually exclusive.
**How to avoid:** Connect ScoreManager only to `wave_completed` for multiplier advancement. Do not also advance on `all_waves_complete`. If needed, `all_waves_complete` can be used for a game-over/reset event only.
**Warning signs:** Wave multiplier jumps two levels at the end of the final wave.

### Pitfall 4: Player Reference Lookup Timing
**What goes wrong:** ScoreManager `_ready()` runs before `world.gd` adds `ShipBFG23` to the "player" group; group lookup returns null; health_changed signal never connected.
**Why it happens:** Autoloads initialize before any scene nodes. `get_first_node_in_group("player")` in `_ready()` always returns null for autoloads.
**How to avoid:** Use `call_deferred("_find_player")` — identical to WaveManager's deferred approach (line 31: `call_deferred("_find_player")`). The deferred call runs after the scene tree is populated.
**Warning signs:** `[ScoreManager] No player found` warning in output; wave multiplier never resets on damage.

### Pitfall 5: Combo Count Off-By-One
**What goes wrong:** Combo of 2 plays at wrong pitch; bonus calculation is shifted by one.
**Why it happens:** D-09 says "first kill = 0 (no combo); second kill = combo of 2" — so `combo_count` starts at 0, becomes 2 on the second kill, not 1.
**How to avoid:** Initialize `combo_count = 0`. On each kill: if `combo_count == 0`, set to 1 (first kill, no audio, no combo active). If `combo_count >= 1`, increment and emit audio. This means audio plays from kill 2 onward, with `pitch_scale = pow(1.0595, combo_count - 1)` where combo_count is the current count (2 = base pitch 1.0, 3 = 1.0595...).

### Pitfall 6: health_changed Triggering on Non-Damage Events
**What goes wrong:** If `health` is modified outside `damage()` (e.g., healing, godmode), the health_changed signal fires unintentionally and resets the wave multiplier.
**Why it happens:** Signal wired to any health change, not just damage.
**How to avoid:** Only emit `health_changed` when `new_health < old_health` (net damage, not healing). In ScoreManager, only reset the multiplier when the signal indicates a decrease: `if new_health < old_health`.
**Warning signs:** Wave multiplier resets when player picks up health packs.

## Code Examples

### ScoreManager Skeleton (recommended structure)
```gdscript
# Source: Based on WaveManager pattern (components/wave-manager.gd) [VERIFIED: codebase read]
class_name ScoreManager
extends Node

signal score_changed(new_score: int, delta: int)
signal multiplier_changed(new_multiplier: int)
signal combo_updated(combo_count: int)
signal combo_expired(bonus_awarded: int)

const MULTIPLIER_CAP: int = 16
const COMBO_TIMEOUT: float = 5.0
const COMBO_BONUS_PER_KILL: int = 25

var total_score: int = 0
var wave_multiplier: int = 1
var combo_count: int = 0

var _player: Node = null
var _combo_timer: Timer = null

func _ready() -> void:
    _combo_timer = Timer.new()
    _combo_timer.wait_time = COMBO_TIMEOUT
    _combo_timer.one_shot = true
    _combo_timer.timeout.connect(_on_combo_expired)
    add_child(_combo_timer)
    call_deferred("_find_player")

func _find_player() -> void:
    _player = get_tree().get_first_node_in_group("player")
    if not _player:
        push_warning("[ScoreManager] No node in group 'player' found")
        return
    _player.health_changed.connect(_on_player_health_changed)
```

### Registering enemy died signals (called from WaveManager or world.gd)
```gdscript
# Called for each enemy after spawn (in WaveManager._spawn_enemy or world._ready)
# WaveManager already has the enemy reference — simplest to connect there
# OR ScoreManager connects from group "enemy" in _process (more coupling)
# RECOMMENDED: WaveManager emits a signal when enemy spawns, OR
# ScoreManager connects to each enemy's died signal from within WaveManager._spawn_enemy

# In wave-manager.gd _spawn_enemy():
func _spawn_enemy(enemy_scene: PackedScene) -> void:
    var enemy := enemy_scene.instantiate()
    enemy.tree_exiting.connect(_on_enemy_tree_exiting)
    # NEW: let ScoreManager know about this enemy
    if ScoreManager:
        enemy.died.connect(ScoreManager._on_enemy_died.bind(enemy))
    enemy.add_to_group("enemy")
    get_parent().add_child(enemy)
    enemy.global_position = _get_spawn_position()
    get_parent().setup_spawn_parent(enemy)
```

### Kill handler and combo logic
```gdscript
func _on_enemy_died(enemy: Body) -> void:
    if not enemy.has_method("get"):
        return
    var base_score: int = enemy.get("score_value") if "score_value" in enemy else 0
    var kill_score: int = base_score * wave_multiplier

    _increment_combo()

    total_score += kill_score
    score_changed.emit(total_score, kill_score)
    print("[ScoreManager] Kill: %s +%d (x%d) = %d | total: %d" % [
        enemy.get_class(), base_score, wave_multiplier, kill_score, total_score
    ])

func _increment_combo() -> void:
    if combo_count == 0:
        combo_count = 1
        _combo_timer.start()
        return
    combo_count += 1
    _combo_timer.start()   # restart timer on each kill
    _play_combo_sound(combo_count)
    combo_updated.emit(combo_count)

func _on_combo_expired() -> void:
    if combo_count < 2:
        combo_count = 0
        return
    var bonus: int = combo_count * COMBO_BONUS_PER_KILL * wave_multiplier
    total_score += bonus
    score_changed.emit(total_score, bonus)
    combo_expired.emit(bonus)
    print("[ScoreManager] Combo x%d expires, bonus +%d" % [combo_count, bonus])
    combo_count = 0
    combo_updated.emit(0)
```

### Wave multiplier advancement
```gdscript
func connect_to_wave_manager(wm: WaveManager) -> void:
    wm.wave_completed.connect(_on_wave_completed)
    wm.all_waves_complete.connect(_on_all_waves_complete)

func _on_wave_completed(_wave_number: int) -> void:
    if wave_multiplier < MULTIPLIER_CAP:
        wave_multiplier = min(wave_multiplier * 2, MULTIPLIER_CAP)
        multiplier_changed.emit(wave_multiplier)
        print("[ScoreManager] Wave complete, multiplier x%d" % wave_multiplier)

func _on_player_health_changed(old_health: int, new_health: int) -> void:
    if new_health < old_health and wave_multiplier > 1:
        wave_multiplier = 1
        multiplier_changed.emit(wave_multiplier)
        print("[ScoreManager] Damage taken, multiplier reset to x1")
```

### Pitch-scaled combo audio
```gdscript
var _combo_audio: AudioStreamPlayer

func _ready() -> void:
    # ... timer setup above ...
    _combo_audio = AudioStreamPlayer.new()
    _combo_audio.stream = preload("res://sounds/combo.wav")
    add_child(_combo_audio)

func _play_combo_sound(combo_count: int) -> void:
    # combo_count 2 = pitch 1.0, 3 = 1.0595, 4 = 1.12, etc.
    _combo_audio.pitch_scale = pow(1.0595, combo_count - 1)
    _combo_audio.play()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global variables in world.gd | Autoload singleton | Godot 4 | Autoload accessible from any script without coupling |
| `static var` singletons | Autoload nodes | Godot 3→4 | Autoloads participate in scene tree (can have child nodes, signals work normally) |

**Deprecated/outdated:**
- `AudioStreamPlayer2D` for UI sounds: positional falloff makes it wrong for UI/feedback audio — use non-positional `AudioStreamPlayer`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Autoload `*` prefix syntax in project.godot registers node (not resource) | Architecture Patterns | Wrong syntax would prevent autoload from functioning; verify in Godot editor or official docs |
| A2 | `AudioStreamPlayer.pitch_scale` property exists and works as stated | Code Examples | Combo pitch would break; verify in Godot 4 docs or by running in editor |
| A3 | `pow(1.0595, combo_count - 1)` produces correct semitone steps | Code Examples | Wrong pitch progression — low risk since D-13 specifies this formula exactly |

## Open Questions

1. **WaveManager signal connection point for ScoreManager**
   - What we know: ScoreManager is an autoload, WaveManager is in `world.tscn`
   - What's unclear: Where exactly does ScoreManager connect to WaveManager signals? Options: (a) ScoreManager uses `get_tree().get_first_node_in_group` to find WaveManager via a "wave_manager" group, or (b) `world.gd` explicitly calls `ScoreManager.connect_to_wave_manager($WaveManager)` in its `_ready()`
   - Recommendation: Option (b) is simpler and explicit — `world.gd` already wires things in `_ready()`. Add a `connect_to_wave_manager(wm: WaveManager)` method to ScoreManager that world.gd calls.

2. **Enemy died signal connection point**
   - What we know: Enemies are spawned by WaveManager, which has access to the instance before `add_child`
   - What's unclear: Should WaveManager connect `died` to ScoreManager directly, or should ScoreManager scan the "enemy" group?
   - Recommendation: WaveManager._spawn_enemy connects `enemy.died` to ScoreManager immediately after instantiation — mirrors WaveManager's existing `tree_exiting` connection at the same callsite.

## Environment Availability

Step 2.6: SKIPPED — Phase 11 is pure GDScript implementation with no external CLI tools, databases, or services. The only runtime dependency is Godot 4.6 editor (for reimporting `combo.wav`), which is confirmed present.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.6 editor | combo.wav reimport, testing | Confirmed | 4.6 (project.godot) | — |
| combo.wav | Combo audio | Exists (file present) | — | Missing .import file — must reimport in editor |

**Missing dependencies with no fallback:**
- `sounds/combo.wav.import` — must be generated by opening project in Godot editor. Without it, `preload("res://sounds/combo.wav")` will fail silently or error. This is a Wave 0 blocker.

## Sources

### Primary (HIGH confidence)
- `components/body.gd` — verified die(), damage() structure, health mutation pattern
- `components/wave-manager.gd` — verified signal declarations, _spawn_enemy(), _on_wave_complete(), timer pattern
- `components/mountable-weapon.gd` — verified Timer.new() / add_child pattern
- `components/enemy-ship.gd` — verified @export pattern for tunable values
- `components/random-audio-player.gd` — verified audio player pattern (AudioStreamPlayer2D, not the right class but good reference)
- `world.gd` — verified player group assignment, WaveManager usage
- `project.godot` — verified Godot 4.6, no existing [autoload] section
- `sounds/` directory listing — verified combo.wav exists, combo.wav.import does NOT exist

### Secondary (MEDIUM confidence)
- Godot 4 autoload documentation pattern (project.godot `[autoload]` with `*` prefix) — consistent with training knowledge but marked [ASSUMED]

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are Godot built-ins verified in codebase
- Architecture: HIGH — patterns are verified by reading actual component files
- Pitfalls: HIGH — most are verified by inspecting live code (missing import file, timing of queue_free, deferred player lookup)
- Audio API details: MEDIUM — pitch_scale API assumed from training knowledge; [ASSUMED] tagged

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (stable Godot APIs, 30-day window)
