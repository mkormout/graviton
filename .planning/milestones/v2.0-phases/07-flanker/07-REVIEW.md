---
phase: 07-flanker
reviewed: 2026-04-12T22:09:23Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - components/flanker.gd
  - prefabs/enemies/flanker/flanker-bullet.tscn
  - prefabs/enemies/flanker/flanker.tscn
  - world.gd
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-04-12T22:09:23Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the Flanker enemy AI script, its bullet and ship scene files, and world.gd. The core
state-machine implementation (IDLING → SEEKING → LURKING → FIGHTING) is sound. Dying guards,
spawn_parent propagation, and the two-dropper pattern (CoinDropper via body.gd, AmmoDropper via
explicit call in `die()`) are all correct.

Three warnings were found: the `body_exited` handler only cancels SEEKING — the Flanker will chase
a player indefinitely once it reaches LURKING or FIGHTING even if the player leaves detection range;
the FIGHTING state has no distance leash (the leash only fires during LURKING); and a timing issue
means a Flanker can complete an entire FIGHTING phase without firing if it entered from a bad angle.
Five info items cover debug prints, missing sprites/textures, and a minor implicit float-to-int
conversion.

## Warnings

### WR-01: `_on_detection_area_body_exited` only resets target during SEEKING — Flanker pursues forever once it reaches LURKING or FIGHTING

**File:** `components/flanker.gd:46-49`

**Issue:** The `body_exited` handler clears `_target` and returns to IDLING only when
`current_state == State.SEEKING`. If the player has moved into LURKING or FIGHTING range, exits
the detection radius, and is still a valid (non-freed) node, `_tick_state` will not catch it
because `is_instance_valid(_target)` returns `true`. The Flanker will continue to orbit, drift, and
fight the player indefinitely with no leash. `max_follow_distance` only triggers in the LURKING
branch (line 84), so a FIGHTING Flanker has no range cutoff at all.

**Fix:**
```gdscript
func _on_detection_area_body_exited(body: Node2D) -> void:
    if body == _target:
        _target = null
        _change_state(State.IDLING)
```

Remove the `current_state == State.SEEKING` guard entirely. Any departure of the tracked target
should reset the AI regardless of state. If state-specific cleanup is needed, handle it inside
`_exit_state`.

---

### WR-02: No distance leash in FIGHTING state — FIGHTING Flanker can pursue player across the entire map

**File:** `components/flanker.gd:95-105`

**Issue:** The LURKING branch applies a hard leash when `dist > max_follow_distance` (line 84),
forcing `effective_drift = 2.0` to pull the Flanker back inward. The FIGHTING branch (lines 95–105)
calls `steer_toward(_target.global_position)` unconditionally with no distance check. If the player
sprints away during a FIGHTING phase, the Flanker will follow forever without ever transitioning
back to LURKING — because `_fight_remaining` only counts down while the state remains FIGHTING
(which it will, because there's no exit condition for excessive distance). This is compounded by
WR-01: if `body_exited` does not reset the state, the Flanker never self-corrects.

**Fix:** Add a distance bail-out in the FIGHTING tick:
```gdscript
State.FIGHTING:
    if dist > max_follow_distance:
        _change_state(State.LURKING)
        return
    var target_angle := to_target.angle()
    # ... rest of FIGHTING logic unchanged
```

---

### WR-03: Flanker can complete a FIGHTING phase without firing if alignment takes longer than `fight_duration`

**File:** `components/flanker.gd:96-105`

**Issue:** Firing is gated on `not _fire_started and absf(angle_difference(rotation, target_angle)) < 0.15` (line 99). If the Flanker enters FIGHTING from a poor angle (e.g., perpendicular
tangential velocity), the lerp rotation at `_turn_speed * delta` may take longer than
`fight_duration` (default 2.5 s) to close the gap. `_fight_remaining` ticks down simultaneously
(line 103), so the phase expires and the Flanker silently returns to LURKING without having fired
once. `_fight_cooldown` is then set to 5.0 s (line 119), so the Flanker is locked out of fighting
for another 5 seconds after a no-op engagement.

**Fix:** Either start the fire timer unconditionally when entering FIGHTING (let the angle gate
only the _initial_ shot) and rely on the timer for subsequent shots, or set `fight_remaining` to a
minimum value that guarantees enough time to rotate:
```gdscript
# In _enter_state, guarantee at least half a turn's worth of time for alignment:
if new_state == State.FIGHTING:
    # Compute worst-case alignment time and pad fight_duration accordingly,
    # or simply start the fire timer immediately and remove the alignment gate
    # from _fire_started (the burst will still land on target once aligned).
    _fight_remaining = fight_duration
    _fire_started = false
    _fire_timer.start()   # fire on timer ticks; _fire() itself is safe to call when off-angle
```

If the goal is "first shot only fires when aimed", at minimum add a fallback:
```gdscript
# In FIGHTING tick, force fire after half the duration has elapsed regardless of angle:
if not _fire_started and _fight_remaining < fight_duration * 0.5:
    _fire_started = true
    _fire()
    _fire_timer.start()
```

---

## Info

### IN-01: Debug `print()` left in `_enter_state`

**File:** `components/flanker.gd:108`

**Issue:** `print("[Flanker] _enter_state: %s" % State.keys()[new_state])` fires on every state
transition at runtime. The base class `EnemyShip._change_state` (enemy-ship.gd:59) already prints
the state transition, so this double-prints on every change.

**Fix:** Remove the print, or wrap it in a debug constant:
```gdscript
func _enter_state(new_state: State) -> void:
    # print("[Flanker] _enter_state: %s" % State.keys()[new_state])
    if new_state == State.FIGHTING:
```

---

### IN-02: `Sprite2D` in `flanker-bullet.tscn` has no texture — bullet is invisible

**File:** `prefabs/enemies/flanker/flanker-bullet.tscn:27-29`

**Issue:** The `Sprite2D` node is declared with no `texture` property. At runtime the bullet is
invisible. The `EnemyBullet._draw()` debug visual (enemy-bullet.gd) compensates at runtime, but
that is explicitly described in that file as a debug override to be replaced. The bullet relies
entirely on debug-draw geometry; no production sprite is wired.

**Fix:** Assign a texture to the `Sprite2D` node. If reusing the minigun bullet sprite:
```
[node name="Sprite2D" type="Sprite2D" parent="."]
rotation = 1.5708
texture = ExtResource("<minigun-bullet-texture-id>")
```

---

### IN-03: `Sprite2D` in `flanker.tscn` has no texture — Flanker ship is invisible

**File:** `prefabs/enemies/flanker/flanker.tscn:46-47`

**Issue:** Same as IN-02 for the Flanker ship node. The ship renders only via `EnemyShip._draw()`
debug geometry (the filled red circle, arc, and yellow arrow). No production sprite is attached.

**Fix:** Assign a ship sprite texture to the `Sprite2D` node.

---

### IN-04: `world.gd` — asteroid spawn reduced to 10; possible dev leftover

**File:** `world.gd:50`

**Issue:** `spawn_asteroids(10)` spawns a total of 8 asteroids (5 small + 4 medium + 1 large, via
the `count * 0.5 / 0.4 / 0.1` ratios). The first wave launches 10 Flankers simultaneously into a
nearly empty world. This is likely a dev/testing setting rather than an intentional balance choice.

**Fix:** Restore to `spawn_asteroids(100)` or document the intentional count in a comment.

---

### IN-05: `world.gd` — float arithmetic in `range()` calls is implicit

**File:** `world.gd:153-160`

**Issue:** `range(count * 0.5)`, `range(count * 0.4)`, `range(count * 0.1)` pass floats to
`range()`. GDScript accepts this and truncates, but the intent is integer division. It can produce
surprising results for non-round counts (e.g., `range(3 * 0.4)` = `range(1.2)` = `range(1)`).

**Fix:**
```gdscript
for x in range(int(count * 0.5)):
for x in range(int(count * 0.4)):
for x in range(int(count * 0.1)):
```
Or use integer division: `count / 2`, `count * 2 / 5`, `count / 10`.

---

_Reviewed: 2026-04-12T22:09:23Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
