---
phase: 11-scoremanager
reviewed: 2026-04-14T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - components/body.gd
  - components/enemy-ship.gd
  - components/score-manager.gd
  - components/ship.gd
  - components/wave-manager.gd
  - world.gd
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-04-14
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 11 introduces `ScoreManager` as a Godot autoload singleton wiring together kill scoring, a combo chain with audio, wave multipliers, and player-damage resets. The overall architecture is sound: signal connections are correctly typed, the deferred `_find_player` pattern matches `WaveManager`, and the combo timer lifecycle is properly one-shot. Five warnings and four informational items were found. No critical (security or data-loss) issues exist.

The most important concern is a **stale signal connection leak** (`_on_player_health_changed`) and a **missing `score_value` property guard** that causes a silent zero-score kill when an enemy does not expose the property. A secondary concern is that `spawn_test_enemy` in `world.gd` bypasses `ScoreManager.register_enemy`, so test enemies never contribute to score.

---

## Warnings

### WR-01: Stale signal connection — player `health_changed` is never disconnected

**File:** `components/score-manager.gd:52`

**Issue:** `_find_player` connects `_player.health_changed` to `_on_player_health_changed` but never stores a `Callable` or disconnects it. If the player node is freed (e.g., in a future respawn flow), the signal connection is destroyed automatically — that part is safe via Godot's ref-counting. However, if `_find_player` is somehow called a second time (or the player is replaced and `_find_player` re-runs), a duplicate connection is added without guard, causing `_on_player_health_changed` to fire multiple times per damage event.

**Fix:** Guard against duplicate connection with `is_connected`:

```gdscript
func _find_player() -> void:
    _player = get_tree().get_first_node_in_group("player")
    if not _player:
        push_warning("[ScoreManager] No node in group 'player' found")
        return
    if not _player.health_changed.is_connected(_on_player_health_changed):
        _player.health_changed.connect(_on_player_health_changed)
    print("[ScoreManager] Connected to player health_changed signal")
```

---

### WR-02: `register_enemy` silently produces zero score when `score_value` is absent

**File:** `components/score-manager.gd:72`

**Issue:** `_on_enemy_died` reads `enemy.score_value if "score_value" in enemy else 0`. This is the correct duck-typing pattern for GDScript, but there is no `push_warning` when the property is absent. The `EnemyShip` base class does export `score_value`, so all concrete enemies inherit it — but if a scene-level override is forgotten or a non-`EnemyShip` node is registered, kills silently score 0. The developer gets no diagnostic.

**Fix:** Emit a warning when `score_value` is missing:

```gdscript
var base_score: int
if "score_value" in enemy:
    base_score = enemy.score_value
else:
    push_warning("[ScoreManager] Enemy '%s' has no score_value — defaulting to 0" % enemy.name)
    base_score = 0
```

---

### WR-03: `spawn_test_enemy` in `world.gd` bypasses `ScoreManager.register_enemy`

**File:** `world.gd:327-332`

**Issue:** `spawn_test_enemy()` adds the enemy to the scene but does not call `ScoreManager.register_enemy(enemy)`. This means killing a test enemy does not increment `kill_count`, does not trigger the combo chain, and does not award score — which makes manual testing misleading.

**Fix:** Register the test enemy with the score manager after instantiation:

```gdscript
func spawn_test_enemy() -> void:
    var enemy = enemy_model.instantiate()
    enemy.global_position = $ShipBFG23.global_position + Vector2(600, 0)
    add_child(enemy)
    setup_spawn_parent(enemy)
    if ScoreManager:
        ScoreManager.register_enemy(enemy)
    print("[World] Test enemy spawned at %s" % enemy.global_position)
```

---

### WR-04: `_on_enemy_died` accesses `enemy` after `queue_free()` has been called

**File:** `components/score-manager.gd:71`

**Issue:** `register_enemy` uses `enemy.died.connect(_on_enemy_died.bind(enemy))`. In `body.gd`, `die()` calls `died.emit()` and then `queue_free()` on the same line (lines 63-64). In Godot 4, `died.emit()` fires synchronously — so `_on_enemy_died(enemy)` receives the node reference while it is still alive *in the current frame*. However, `enemy.get_script().get_global_name()` at line 82 dereferences the object. If any future refactor moves `died.emit()` to occur after `queue_free()` (or the signal is emitted from a deferred context), this dereference becomes a use-after-free.

More immediately: `"score_value" in enemy` and `enemy.score_value` are safe now (emit is before free), but `enemy.get_script()` at line 82 can return `null` even for a live node if the script was not attached — calling `.get_global_name()` on null crashes.

**Fix:** Guard the `get_script()` call (already partially done with a ternary, but make the null check explicit):

```gdscript
var script = enemy.get_script()
var enemy_type: String = script.get_global_name() if script else "Unknown"
```

The existing line 82 already does this correctly — but add a comment noting that `score_value` must be read before the node is freed, i.e., at signal-emit time (not deferred).

---

### WR-05: `_on_combo_expired` emits `combo_updated(0)` only on the multi-kill branch

**File:** `components/score-manager.gd:105-118`

**Issue:** When `combo_count < 2` (single-kill timeout, lines 106-109), the method returns early after resetting `combo_count = 0` but does **not** emit `combo_updated.emit(0)`. If the HUD listens to `combo_updated` to hide a combo counter, it will never receive the reset signal for single-kill cases, leaving the counter stuck at 1 (which `combo_updated` was never actually emitted for either — `_increment_combo` returns early at `combo_count == 0` in the first-kill case). This is technically consistent, but if a future HUD initialises combo display at 1 after the first kill, it will not be cleared on timeout.

**Fix:** Unify the reset path so `combo_updated(0)` is always emitted when the timer expires:

```gdscript
func _on_combo_expired() -> void:
    if combo_count >= 2:
        var bonus: int = combo_count * COMBO_BONUS_PER_KILL * wave_multiplier
        total_score += bonus
        score_changed.emit(total_score, bonus)
        combo_expired.emit(bonus)
        print("[ScoreManager] Combo x%d expires, bonus +%d | total: %d" % [combo_count, bonus, total_score])
    combo_count = 0
    combo_updated.emit(0)
```

---

## Info

### IN-01: `_increment_combo` does not emit `combo_updated` on the first kill

**File:** `components/score-manager.gd:90-95`

**Issue:** When `combo_count == 0`, the method sets `combo_count = 1` and returns without emitting `combo_updated.emit(1)`. This is intentional per the comment ("First kill in potential chain — no audio yet"), but any HUD consumer of `combo_updated` will not know a potential combo has started. If Phase 12 HUD needs to show a "building" indicator from kill 1, this will need revisiting.

**Fix:** No change required now — document the intentional asymmetry with a comment:

```gdscript
# NOTE: combo_updated is NOT emitted for the first kill (count=1).
# HUD should only show the combo indicator once count reaches 2.
```

---

### IN-02: Debug `print` statements throughout `ScoreManager` and `WaveManager`

**Files:** `components/score-manager.gd:53,86,102,116,137,147` | `components/wave-manager.gd:43,79,129,135`

**Issue:** Production autoload and manager classes contain `print()` calls for every state transition. These are acceptable during development but should be gated behind a debug flag before shipping.

**Fix:** Add `const DEBUG: bool = false` at the top of each class and wrap prints:

```gdscript
if DEBUG: print("[ScoreManager] ...")
```

---

### IN-03: `EnemyShip._draw()` runs every physics frame via `queue_redraw()` in `_physics_process`

**File:** `components/enemy-ship.gd:34-36`

**Issue:** `queue_redraw()` is called unconditionally every `_physics_process` tick. `_draw()` performs multiple string formatting operations, font lookups (`ThemeDB.fallback_font`), and node queries (`get_node_or_null`). This is a debug visualization and should be conditional.

**Fix:** Gate `queue_redraw()` behind a debug export flag:

```gdscript
@export var debug_draw: bool = false

func _physics_process(delta: float) -> void:
    super(delta)
    if debug_draw:
        queue_redraw()
    ...
```

---

### IN-04: `world.gd` has no `class_name` declaration

**File:** `world.gd:1`

**Issue:** All other scripts in this codebase declare `class_name` at the top (`Body`, `Ship`, `WaveManager`, `EnemyShip`, `ScoreManager`). `world.gd` omits this, which is inconsistent with the project convention stated in `CLAUDE.md`. The script is the main scene script so it is never referenced by type, but consistency aids searchability.

**Fix:** Add at the top of `world.gd`:

```gdscript
class_name World
extends Node2D
```

---

_Reviewed: 2026-04-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
