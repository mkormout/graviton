---
phase: 12-score-hud
reviewed: 2026-04-15T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - prefabs/ui/score-hud.tscn
  - prefabs/ui/score-hud.gd
  - world.gd
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-04-15
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three files reviewed: the ScoreHud scene and script (`prefabs/ui/score-hud.tscn`, `prefabs/ui/score-hud.gd`) and the world entry point (`world.gd`). `score-manager.gd` was read as a cross-reference for signal contracts.

The HUD wiring is correct and signals connect cleanly. Two behaviour defects stand out: (1) the score flash animation is inverted — it starts at the intended peak colour and tweens toward a dimmer shade rather than flashing bright, and (2) the kills label bypasses the signal-driven data flow by reading the `ScoreManager` autoload directly, which also makes `connect_to_score_manager` brittle. One additional correctness issue exists in `world.gd` where the null-guard for `ScoreManager` covers only two lines but leaves the dependent `score_hud.connect_to_score_manager(ScoreManager)` call unguarded.

---

## Warnings

### WR-01: Score flash animation is inverted

**File:** `prefabs/ui/score-hud.gd:58-64`
**Issue:** `_animate_score_flash` immediately snaps `_score_value` to `Color.WHITE`, then tweens _toward_ `Color(1.0, 1.0, 0.7)` (a warm cream/yellow), then back to `Color.WHITE`. The intent of a "score flash" is to peak at a bright/warm colour and return to the resting colour. As written the label rests at `WHITE`, briefly drifts toward cream-yellow, then returns — the opposite of a flash. The `Color.WHITE` snap and the final tween destination should be swapped so the animation peaks at the warm yellow and returns to white.

**Fix:**
```gdscript
func _animate_score_flash() -> void:
    if _score_tween and _score_tween.is_running():
        _score_tween.kill()
    # Snap to the peak flash colour, then fade back to resting white
    _score_value.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
    _score_tween = _score_value.create_tween()
    _score_tween.tween_property(_score_value, "theme_override_colors/font_color", Color.WHITE, 0.3)
```

---

### WR-02: Kills label reads autoload directly instead of signal data

**File:** `prefabs/ui/score-hud.gd:35`
**Issue:** `_on_score_changed` reads `ScoreManager.kill_count` directly from the global autoload instead of receiving the value through the injected `sm` reference or a dedicated signal. This breaks the decoupling established by `connect_to_score_manager(sm: Node)` — if `ScoreManager` is renamed, the script is extracted for reuse, or the node is tested in isolation, this line silently reads stale data or crashes. The `score_changed` signal carries `new_score` and `delta` but not `kill_count`; the cleanest fix is to emit `kill_count` as part of `score_changed` or add a separate `kill_count_changed` signal.

**Fix (minimal — use injected reference):**
```gdscript
# In score-hud.gd — store the injected reference
var _score_manager: Node = null

func connect_to_score_manager(sm: Node) -> void:
    _score_manager = sm
    sm.score_changed.connect(_on_score_changed)
    sm.multiplier_changed.connect(_on_multiplier_changed)
    sm.combo_updated.connect(_on_combo_updated)
    sm.combo_expired.connect(_on_combo_expired)

func _on_score_changed(new_score: int, _delta: int) -> void:
    _score_value.text = "%d" % new_score
    _kills_value.text = "%d" % _score_manager.kill_count  # use stored ref, not global
    _animate_score_flash()
```

**Fix (clean — extend the signal):**
In `score-manager.gd`, add `kill_count` to the `score_changed` signal:
```gdscript
signal score_changed(new_score: int, delta: int, kill_count: int)
# emit site:
score_changed.emit(total_score, kill_score, kill_count)
```
Then in `score-hud.gd`:
```gdscript
func _on_score_changed(new_score: int, _delta: int, kills: int) -> void:
    _score_value.text = "%d" % new_score
    _kills_value.text = "%d" % kills
    _animate_score_flash()
```

---

### WR-03: `ScoreManager` null-guard in `world.gd` does not cover `connect_to_score_manager` call

**File:** `world.gd:60-65`
**Issue:** The `if ScoreManager:` guard on line 60 protects only `ScoreManager.connect_to_wave_manager($WaveManager)` (line 61). Lines 63–65 instantiate `score_hud` and call `score_hud.connect_to_score_manager(ScoreManager)` unconditionally, outside the guard. If `ScoreManager` were ever absent (null autoload, renamed node), `connect_to_score_manager` would receive `null` and the four `sm.X.connect(...)` calls inside it would crash at runtime without a clear error message.

```gdscript
# Current — guard only covers line 61
if ScoreManager:
    ScoreManager.connect_to_wave_manager($WaveManager)   # line 61

var score_hud: ScoreHud = score_hud_model.instantiate() # line 63 — unguarded
add_child(score_hud)                                     # line 64
score_hud.connect_to_score_manager(ScoreManager)         # line 65 — passes null if guard would have failed
```

**Fix:** Extend the guard to cover all `ScoreManager`-dependent code:
```gdscript
if ScoreManager:
    ScoreManager.connect_to_wave_manager($WaveManager)
    var score_hud: ScoreHud = score_hud_model.instantiate()
    add_child(score_hud)
    score_hud.connect_to_score_manager(ScoreManager)
```

---

## Info

### IN-01: `connect_to_score_manager` parameter is untyped `Node`

**File:** `prefabs/ui/score-hud.gd:26`
**Issue:** The parameter `sm: Node` accepts any `Node`, losing static type information. `ScoreManager` does not declare `class_name` in `components/score-manager.gd`, so it cannot be used as a type here directly. Adding `class_name ScoreManager` to `score-manager.gd` would allow typing the parameter properly and make signal connection errors detectable at edit time rather than runtime.

**Fix:** Add `class_name ScoreManager` at the top of `components/score-manager.gd`, then update the parameter:
```gdscript
func connect_to_score_manager(sm: ScoreManager) -> void:
```

---

### IN-02: Redundant double-reset on combo expiry in `score-manager.gd`

**File:** `components/score-manager.gd:103-108`
**Issue:** `_on_combo_expired` emits `combo_expired` (line 107) then immediately emits `combo_updated(0)` (line 108). `ScoreHud` handles both — `_on_combo_expired` resets the label to `--` and grey, then `_on_combo_updated(0)` does exactly the same reset again. The second emit is a no-op from the HUD's perspective. This is harmless but adds an unnecessary signal round-trip on every combo expiry.

**Fix:** Remove the redundant `combo_updated.emit(0)` call on line 108 — `combo_expired` already carries the full reset semantics — or remove the `combo_expired` signal entirely and let `combo_updated(0)` serve as the unified expiry notification. Pick one.

---

_Reviewed: 2026-04-15_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
