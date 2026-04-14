---
phase: 09-suicider
reviewed: 2026-04-13T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - components/enemy-ship.gd
  - components/explosion.gd
  - components/suicider.gd
  - prefabs/enemies/beeliner/beeliner.tscn
  - prefabs/enemies/flanker/flanker.tscn
  - prefabs/enemies/sniper/sniper.tscn
  - prefabs/enemies/suicider/suicider-explosion.tscn
  - prefabs/enemies/suicider/suicider.tscn
  - prefabs/enemies/swarmer/swarmer.tscn
  - world.gd
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-04-13T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed the Suicider enemy implementation and supporting explosion infrastructure. The `suicider.gd` script, `suicider.tscn` scene, and `suicider-explosion.tscn` are the primary new additions. The explosion system (`explosion.gd`) and base class (`enemy-ship.gd`) were reviewed for interaction correctness.

One critical bug was found: a duplicate signal connection that prevents the Suicider from ever acquiring its target. Two warnings cover an unsafe debris instantiation path in `explosion.gd` and a fragile debris-generation guard. Three informational items cover missing loot drop configuration, absent debug-draw guards, and a non-standard manual UID.

## Critical Issues

### CR-01: Duplicate signal connection prevents Suicider from acquiring target

**File:** `components/suicider.gd:18`

**Issue:** `Suicider._ready()` calls `super()` on line 12, which runs `EnemyShip._ready()`. That method connects `detection_area.body_entered` to `_on_detection_area_body_entered` (enemy-ship.gd:30) — binding the *base class* handler. Immediately after, `Suicider._ready()` line 18 connects the same signal again to the *Suicider override* of `_on_detection_area_body_entered`. Both connections survive; Godot does not deduplicate them.

When a `PlayerShip` enters the detection area, both handlers fire:

1. `EnemyShip._on_detection_area_body_entered` fires first. It sees `current_state == State.IDLING` and calls `_change_state(State.SEEKING)`. **It does not set `_target`.**
2. `Suicider._on_detection_area_body_entered` fires second. By this point `current_state == State.SEEKING`, so the guard `current_state == State.IDLING` is now false — `_target` is **never assigned**.

On the next `_tick_state` call, `is_instance_valid(_target)` returns false (target is null), the state immediately reverts to `IDLING`, and the Suicider stands still forever after detection.

**Fix:** Remove the redundant `connect` call from `Suicider._ready()`. The base class already connects the signal; the Suicider only needs to override the handler method (which it already does via GDScript virtual dispatch — but signals in Godot bind to the specific callable at connection time, not via vtable). The correct fix is to **not** connect in `EnemyShip._ready()` at all, and let each concrete subclass connect in its own `_ready()`, or use a template-method pattern where the base connects once but calls a virtual `_handle_detection(body)`:

```gdscript
# enemy-ship.gd — remove the detection connect from _ready()
func _ready() -> void:
    super()
    detection_area.set_collision_layer_value(1, false)
    detection_area.set_collision_mask_value(1, true)
    detection_area.body_entered.connect(_on_detection_area_body_entered)
    hitbox.body_entered.connect(_on_hitbox_body_entered)

# The base handler calls a virtual method instead of acting directly:
func _on_detection_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    _handle_detection(body)

func _handle_detection(body: Node2D) -> void:
    # Base: transition to SEEKING on player detection
    if body is PlayerShip and current_state == State.IDLING:
        _change_state(State.SEEKING)

# suicider.gd — override the virtual, do NOT re-connect the signal
func _handle_detection(body: Node2D) -> void:
    if body is PlayerShip and current_state == State.IDLING:
        _target = body
        _change_state(State.SEEKING)
```

Alternatively, the minimal fix is to remove only the reconnect from `suicider.gd` and set `_target` inside `_enter_state` instead (it already partially does this — `_enter_state` sets `_locked_target_pos` but cannot set `_target` because the base class fires first without providing the body reference). The cleanest minimal fix:

```gdscript
# suicider.gd _ready() — remove the duplicate connect (line 18):
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    _contact_area.set_collision_layer_value(1, false)
    _contact_area.set_collision_mask_value(1, true)
    # REMOVE: detection_area.body_entered.connect(_on_detection_area_body_entered)
    _contact_area.body_entered.connect(_on_contact_area_body_entered)

# And override _on_detection_area_body_entered so the base-class connect
# picks up the Suicider's version instead (GDScript does NOT do this automatically
# for signals bound at connect-time — use a virtual dispatch helper as shown above)
```

The cleanest production fix is the virtual `_handle_detection` pattern shown above.

---

## Warnings

### WR-01: `generate_debris()` crashes if `debris_count > 0` but `debris` array is empty

**File:** `components/explosion.gd:69`

**Issue:** `debris.pick_random()` on an empty `Array[PackedScene]` returns `null`. Calling `null.instantiate()` on the next line causes a null-reference crash. This path is not hit by `suicider-explosion.tscn` (which leaves `debris_count` at the default of 0), but any future explosion scene that sets `debris_count` without populating `debris` will crash silently at runtime.

**Fix:**
```gdscript
func generate_debris():
    if debris.is_empty() or debris_count == 0:
        return
    var MIN_RANGE = 0
    var MAX_RANGE = radius
    var MAX_ANGULAR_VELOCITY = PI / 2
    for i in range(debris_count):
        var model = debris.pick_random()
        if not model:
            continue
        var node = model.instantiate() as RigidBody2D
        # ... rest of function unchanged
```

### WR-02: Suicider `die()` calls base `die()` with no explosion spawn parent set at call time

**File:** `components/suicider.gd:68-72` and `prefabs/enemies/suicider/suicider.tscn`

**Issue:** `suicider.tscn` does not have an `item_dropper` node configured, which is fine and intentional. However, `body.gd:die()` spawns the `death` scene (`suicider-explosion.tscn`) using `spawn_parent.add_child(node)` (body.gd:46). The `spawn_parent` is injected by `world.gd:setup_spawn_parent()` after instantiation. If the Suicider is ever instantiated without `setup_spawn_parent` being called (e.g., spawned by a `WaveManager` that does not propagate spawn_parent), the explosion falls back to `push_warning` with no visual effect — the kamikaze explosion silently fails.

All current wave spawning goes through `WaveManager`, so this depends on whether `WaveManager` calls `setup_spawn_parent`. If it does not, the Suicider will die silently with no explosion. This is a latent bug dependent on `WaveManager` implementation.

**Fix:** Verify that `WaveManager.spawn_enemy()` (or equivalent) calls `world.setup_spawn_parent()` on each spawned enemy. Consider adding an assertion or warning in `body.gd:die()` that is louder than `push_warning` when `spawn_parent` is null and a `death` scene is configured.

---

## Info

### IN-01: Suicider has no loot drop configured

**File:** `prefabs/enemies/suicider/suicider.tscn`

**Issue:** Unlike beeliner, flanker, sniper, and swarmer — which all have `CoinDropper` and `AmmoDropper` child nodes — the Suicider scene has no `item_dropper` property and no dropper nodes. The player receives no reward for surviving a Suicider attack. This may be intentional design (kamikaze = no loot), but it should be a conscious choice.

**Fix:** If intentional, add a comment to `suicider.tscn` confirming no loot is by design. If unintentional, add a `CoinDropper` node following the same pattern as `beeliner.tscn` lines 74-76.

### IN-02: Debug draw in `_draw()` has no build-type guard

**File:** `components/enemy-ship.gd:66-86`

**Issue:** The `_draw()` override renders collision radius arcs, direction arrows (500-unit yellow arrow), and large cyan text labels on every enemy every frame. These are development aids that will appear in release builds. The label uses a 128-point font rendered in world space — visible at any zoom level.

**Fix:**
```gdscript
func _draw() -> void:
    if not OS.is_debug_build():
        return
    # ... existing draw calls
```

### IN-03: Manual UID strings in suicider scenes may cause future collisions

**File:** `prefabs/enemies/suicider/suicider.tscn:1`, `prefabs/enemies/suicider/suicider-explosion.tscn:1`

**Issue:** `suicider.tscn` uses `uid="uid://suicider_scene_001"` — a human-readable UID. Godot generates random UIDs (e.g., `uid://drkuv3ul7es3i`) to guarantee uniqueness. Hand-crafted UIDs are not validated for collisions by the engine at load time. If another asset is later given a colliding UID (or if the UID registry becomes inconsistent), Godot's resource loader will silently use whichever was loaded first.

**Fix:** Let Godot regenerate proper UIDs by removing the `uid=` line and re-saving the scenes in the editor. The reference in `suicider.tscn` line 4 (`uid="uid://suicider_explosion_1"`) and `suicider-explosion.tscn` line 1 match correctly, so the link is internally consistent — but regenerating both together is still the safer long-term approach.

---

_Reviewed: 2026-04-13T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
