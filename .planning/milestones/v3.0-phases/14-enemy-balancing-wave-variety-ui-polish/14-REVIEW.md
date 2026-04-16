---
phase: 14-enemy-balancing-wave-variety-ui-polish
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - components/beeliner.gd
  - components/flanker.gd
  - components/sniper.gd
  - components/swarmer.gd
  - components/ship.gd
  - components/wave-manager.gd
  - prefabs/ui/wave-hud.gd
  - prefabs/ui/controls-hint.gd
  - world.gd
  - prefabs/enemies/beeliner/beeliner.tscn
  - prefabs/enemies/sniper/sniper.tscn
  - prefabs/enemies/flanker/flanker.tscn
  - prefabs/enemies/swarmer/swarmer.tscn
  - prefabs/enemies/suicider/suicider.tscn
  - prefabs/enemies/suicider/suicider-explosion.tscn
  - prefabs/ui/wave-hud.tscn
  - prefabs/ui/controls-hint.tscn
findings:
  critical: 0
  warning: 5
  info: 8
  total: 13
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Phase 14 introduced enemy stat buffs, AI behavioural tweaks (jitter, sinusoidal strafe, patrol fixes, speed tiers), a WaveManager refactor to manual wave advancement, WaveHud improvements, and a ControlsHint toggle panel wired into `world.gd`.

The overall implementation quality is solid. The WaveManager refactor is clean, the manual-advance flow (Enter / F key) is correct, and the AI state machines are well-structured. No security issues were found. No critical bugs were found.

Five warnings were identified — three logic/correctness issues and two robustness gaps — along with eight informational items covering debug noise, magic constants, stale scene properties, and minor code-smell items.

---

## Warnings

### WR-01: `_on_wave_completed` hides the wave-clear label, not shows it

**File:** `prefabs/ui/wave-hud.gd:60-62`
**Issue:** `_on_wave_completed` unconditionally hides `_wave_clear_label`. It runs immediately when a wave ends, which races with `_on_wave_cleared_waiting` (emitted right after on the same frame for non-final waves). In practice the label is hidden before it has a chance to appear, making the "press Enter/F to continue" prompt invisible for all non-final waves.

The intent is almost certainly "dismiss any stale label from the *previous* wave". But the signal order in `_on_wave_complete()` (wave-manager.gd line 128) emits `wave_completed` first, then `wave_cleared_waiting`. Both handlers run synchronously, so the label appears briefly and is immediately hidden — or may never render at all depending on engine flush order.

**Fix:** Either remove the redundant hide from `_on_wave_completed` (the `_on_wave_started` handler already hides it at line 28), or rename the intent clearly:

```gdscript
func _on_wave_completed(_wave_number: int) -> void:
    # Nothing to do here; _on_wave_started handles cleanup when the next
    # wave launches. Keeping the signal connected for future use.
    pass
```

---

### WR-02: `speed_tier` prop-set guard uses `!= 1.0` float comparison

**File:** `components/wave-manager.gd:87`
**Issue:** `if speed_tier != 1.0 and enemy.get("speed_tier") != null` skips the assignment when `speed_tier` is exactly 1.0. This is intentional as an optimisation, but the comment says "Set speed_tier BEFORE add_child so _ready() receives it". If the wave definition passes `speed_tier: 1.0` explicitly (a valid future use case), the value is silently not applied — meaning `randf_range(0.8, 1.2)` multipliers in `swarmer._ready()` stack on top of the scene-default `speed_tier = 1.0` either way, so there is no current bug. However, the guard creates a silent inconsistency if anyone passes `1.0` expecting the property to be freshly set.

More importantly: `enemy.get("speed_tier") != null` returns `null` for any enemy that does not have a `speed_tier` property, which is correct. But for enemies that do have it set to a non-null default (e.g. the Swarmer scene sets `speed_tier = 1.0`), the condition evaluates to `false` only because of the `!= 1.0` guard, not because the property is absent. This is fragile.

**Fix:** Separate the "does this enemy type support speed_tier" check from the "is the value non-default" skip:

```gdscript
if enemy.get("speed_tier") != null and speed_tier != 1.0:
    enemy.speed_tier = speed_tier
```

Order of operands matters — the short-circuit already avoids setting on incompatible types. Document that `1.0` is intentionally skipped to avoid touching the randomised multipliers in `_ready()`.

---

### WR-03: `Flanker._tick_state` calls `_change_state(State.IDLING)` for every invalid target, even during FIGHTING

**File:** `components/flanker.gd:53-57`
**Issue:** The top-of-function guard at lines 53-57 transitions to IDLING whenever `_target` is invalid, regardless of `current_state`. This means a Flanker in FIGHTING or LURKING state that loses its target (e.g. player dies) always drops directly to IDLING, bypassing any cleanup in `_exit_state(State.LURKING)` or `_exit_state(State.FIGHTING)`. Currently `_exit_state(FIGHTING)` stops the fire timer and sets the fight cooldown — skipping this on player death means the fire timer keeps running and `_fight_cooldown` is never reset.

`Beeliner` and `Swarmer` have the same pattern but their `_exit_state` handlers are simpler (just `_fire_timer.stop()`), so the risk is lower.

**Fix:** Route through `_change_state` from all guards to ensure cleanup hooks run:

```gdscript
func _tick_state(_delta: float) -> void:
    if not is_instance_valid(_target):
        _target = null
        if current_state != State.IDLING:
            _change_state(State.IDLING)
        return
    # ... rest unchanged
```

This is already correct in `sniper.gd` (line 49-50) — apply the same pattern to `flanker.gd` and `swarmer.gd`.

---

### WR-04: `WaveManager._on_wave_complete` emits `wave_completed` with the post-increment index

**File:** `components/wave-manager.gd:128-133`
**Issue:** `_current_wave_index` is incremented at line 70 (`_current_wave_index += 1`) before any signals fire. `_on_wave_complete` (line 128) then emits `wave_completed.emit(_current_wave_index)` using the already-incremented index. For example, completing wave 1 emits `wave_completed(2)`, and `_on_wave_cleared_waiting` emits `wave_cleared_waiting(2)`. The WaveHud uses `wave_number` in the "WAVE %d CLEARED" text, so the UI displays the *next* wave number rather than the wave that was actually cleared.

**Fix:** Emit with the 1-based current wave number, which is `_current_wave_index` after increment (i.e. already correct as a display ordinal for `wave_started`). However `wave_completed` is semantically "wave N just finished", so it should emit the index of the wave that completed. Capture before the increment or subtract 1 when emitting from `_on_wave_complete`:

```gdscript
func _on_wave_complete() -> void:
    var completed_wave := _current_wave_index  # post-increment, so this is 1-based wave number
    print("[WaveManager] Wave %d complete!" % completed_wave)
    wave_completed.emit(completed_wave)
    if _current_wave_index >= waves.size():
        all_waves_complete.emit()
    else:
        wave_cleared_waiting.emit(completed_wave)
```

Actually `_current_wave_index` after increment equals the 1-based number of the wave that just completed, which is what both signals should carry. The current code is numerically consistent — this is primarily a semantic clarity issue. Verify that all subscribers expect 1-based (post-increment) numbering; the WaveHud uses it for display only, so the visual output will say "WAVE 2 CLEARED" when wave 2 has just been cleared. Cross-check with `wave_started` which uses the same post-increment value: `wave_started.emit(_current_wave_index, ...)` at line 71 — that value is "wave 1" when `_current_wave_index` was 0 before trigger. So the convention is consistent. **The real bug is in WR-01**, not here — flag lowered to Warning because the index semantics are at least internally consistent, but this warrants a comment.

---

### WR-05: `Swarmer._on_detection_area_body_exited` resets state regardless of current state

**File:** `components/swarmer.gd:53-56`
**Issue:** Unlike Flanker and Sniper (which guard with `current_state == State.SEEKING`), Swarmer drops target and transitions to IDLING whenever the player exits the detection area — even if the Swarmer is in FIGHTING state. This means a Swarmer that has closed to firing range and has the player overlapping its detection area boundary (possible given detection_radius=10000 and fight_range=10000 are equal in the scene) may sporadically lose state mid-fight as the player crosses the detection circle boundary.

**Fix:** Apply the same guard as Sniper/Flanker:

```gdscript
func _on_detection_area_body_exited(body: Node2D) -> void:
    if body == _target and current_state == State.SEEKING:
        _target = null
        _change_state(State.IDLING)
```

The existing `is_instance_valid(_target)` check at the top of `_tick_state` provides a fallback for freed nodes, so this is safe to tighten.

---

## Info

### IN-01: Debug `print` statements left in production paths

**Files:**
- `components/beeliner.gd:52, 69, 81`
- `components/flanker.gd:111`
- `components/sniper.gd:92, 128`
- `components/swarmer.gd:140`
- `components/wave-manager.gd:35, 38, 67, 122, 128`
- `components/enemy-ship.gd:60` (base class, out of scope but called by all)

Per project conventions, commented-out `print()` calls are acceptable as lightweight debug markers. However the current prints are *active* (not commented), including hot-path per-bullet spawns (`beeliner.gd:81`) and per-state transitions (`enemy-ship.gd:60`). At 20 waves × up to 38 enemies × multiple state transitions each, this will produce significant console noise and minor GC pressure from string interpolation.

**Fix:** Comment out or remove prints that fire every bullet or state change. The `[WaveManager]` prints for wave start/enemy-death are useful operational diagnostics and can stay.

---

### IN-02: Magic constant `5510.0` in `WaveManager._get_spawn_position` should be a named constant

**File:** `components/wave-manager.gd:114`
**Issue:** `var base_radius: float = 5510.0 + spawn_radius_margin` — the value `5510.0` is derived from viewport dimensions (1920x1080 half-diagonal at zoom 0.2) and buried in a comment. If the viewport or zoom changes, this number silently becomes stale.

**Fix:**
```gdscript
const VIEWPORT_HALF_DIAGONAL: float = 5510.0  # 1920×1080 half-diag at zoom 0.2
var base_radius: float = VIEWPORT_HALF_DIAGONAL + spawn_radius_margin
```

---

### IN-03: `Beeliner` scene `.tscn` declares a `Barrel` node but `beeliner.gd` does not reference it

**File:** `prefabs/enemies/beeliner/beeliner.tscn:79`
**Issue:** The `Barrel` node (position `Vector2(40, 0)`) exists in the scene but `beeliner.gd` spawns bullets at `global_position + fire_dir * 350.0` (a hardcoded offset) instead of `$Barrel.global_position`. The other enemies (Flanker, Sniper, Swarmer) all use `_barrel.global_position`. This is inconsistent and the `350.0` magic offset was chosen to clear the HitBox radius — but the `Barrel` node is unused and misleading.

**Fix:** Either remove the `Barrel` node from `beeliner.tscn`, or refactor `beeliner.gd` to use `@onready var _barrel: Node2D = $Barrel` and spawn at `_barrel.global_position` (matching the other enemy types).

---

### IN-04: `Beeliner.tscn` `fight_range` scene override (16000) inconsistent with script default (400) and `sniper.tscn` equivalent gap

**File:** `prefabs/enemies/beeliner/beeliner.tscn:50`
**Issue:** `beeliner.gd` exports `fight_range: float = 400.0` but the scene sets it to `16000.0`. Similarly, `sniper.tscn` exports `fight_range = 22000.0` against the script default of `11000.0`. Having the canonical design values exist only in `.tscn` files (not in the script defaults) makes it easy to accidentally break them if the scene is re-saved without the override. It also makes the script defaults misleading when reading the `.gd` file alone.

**Fix:** Update the GDScript `@export` default values to match the design-intent values from the scene files, or add a comment in each script noting that the scene overrides the default.

---

### IN-05: `WaveHud._on_countdown_tick` is wired but `WaveManager` never emits `countdown_tick`

**File:** `prefabs/ui/wave-hud.gd:48-53` and `components/wave-manager.gd` (full file)
**Issue:** `WaveHud.connect_to_wave_manager` connects to `wm.countdown_tick`, and `WaveHud._on_countdown_tick` shows/hides `_countdown_label`. `WaveManager` declares the `countdown_tick` signal at line 6 but never emits it. The `_countdown_label` will therefore never be shown. This is dead UI code that may confuse future contributors.

**Fix:** Either implement a countdown timer in `WaveManager` and emit `countdown_tick`, or remove `_countdown_label` from the scene and `_on_countdown_tick` from `wave-hud.gd` if the auto-advance feature is not planned.

---

### IN-06: `Flanker.tscn` `fight_range` scene property (9000) differs from script default (4500) without a comment

**File:** `prefabs/enemies/flanker/flanker.tscn:48`
**Issue:** Same pattern as IN-04. Script default `fight_range = 4500.0`, scene sets `9000.0`. No comment in the script explaining the intent difference.

---

### IN-07: `controls-hint.tscn` `RichTextLabel` has `anchor_bottom = 1.076` — out-of-range anchor value

**File:** `prefabs/ui/controls-hint.tscn:43`
**Issue:** `anchor_bottom = 1.076` is outside the normalised 0–1 range for Godot anchors. Godot accepts this but it means the label intentionally overflows its container. This is likely a Godot editor rounding artefact. The `offset_bottom = 0.255934` (a sub-pixel float) suggests the layout was set by the editor and never manually reviewed.

**Fix:** Review the layout in the editor and snap the anchor to `1.0` if the label is meant to fill its container, or use `layout_mode = 2` with a parent that auto-sizes.

---

### IN-08: `world.gd` `spawn_asteroids` uses `count * 0.5` integer float multiplication without explicit cast

**File:** `world.gd:349-354`
**Issue:** `for x in range(count * 0.5)` — in GDScript 4, `range()` accepts floats by truncating to int, but this is relying on implicit behaviour. `range(count * 0.4)` and `range(count * 0.1)` compound this; for `count=10`, the ratios sum to `5 + 4 + 1 = 10` which is correct, but for odd counts the truncation is silent. The total spawned will silently differ from `count` for non-multiples-of-10.

**Fix:**
```gdscript
func spawn_asteroids(count: int):
    for x in range(count / 2):          # integer division
        add_asteroid(asteroids_small_model.pick_random())
    for x in range(count * 2 / 5):      # integer division
        add_asteroid(asteroids_medium_model.pick_random())
    for x in range(count / 10):
        add_asteroid(asteroids_large_model.pick_random())
```

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
