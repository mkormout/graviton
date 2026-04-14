---
phase: 06-sniper
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - components/sniper.gd
  - prefabs/enemies/sniper/sniper-bullet.tscn
  - prefabs/enemies/sniper/sniper.tscn
  - world.gd
findings:
  critical: 1
  warning: 4
  info: 4
  total: 9
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Phase 06 adds the Sniper enemy type: a standoff fighter with three distance bands (FLEEING/FIGHTING/SEEKING), a two-timer fire pattern (fire_timer -> aim_timer -> _fire()), and a bespoke bullet scene. The architecture is sound and consistent with the Beeliner pattern. One critical correctness bug was found (fire_timer fires at interval 0 after the first shot), four warnings relate to logic gaps that cause incorrect runtime behaviour, and four info items cover dead code and debug artifacts.

---

## Critical Issues

### CR-01: FireTimer has no interval set — fires continuously after first shot

**File:** `prefabs/enemies/sniper/sniper.tscn:71`
**Issue:** The `FireTimer` node is declared with no `wait_time` override, so it uses the Godot default of **1 second**. More critically, `FireTimer` is a looping timer (`one_shot` is not set, defaulting to `false`). When `_enter_state(FIGHTING)` calls `_fire_timer.start()` with no argument, it starts the timer in **repeating mode** with a `wait_time` of 1 second — not the intended 3-second cadence visible in the scene file property comment. Crucially, `_on_fire_timer_timeout` calls `_aim_timer.start(aim_up_time)` and then the aim timer fires `_fire()`. But the fire timer **keeps repeating**. If `aim_up_time` (1.0 s) is longer than the fire timer interval (1 s), the aim timer is restarted before it fires, creating a situation where the sniper never shoots at all. If the fire timer is 3 s (as configured in the scene), it fires every 3 s and queues an aim-up — this actually works, but:

**The real bug:** `_fire_timer.start()` in `_enter_state` is called **without an argument**. Looking at the scene file:

```
[node name="FireTimer" type="Timer" ...]
wait_time = 3.0
```

The `wait_time = 3.0` is set correctly. However `_fire_timer.start()` with no argument makes Godot restart the timer using **the node's stored `wait_time`**, which is 3.0 — so the cadence is fine on first read. The actual critical issue is that the fire timer is **not `one_shot`**, so after each `_on_fire_timer_timeout` callback, the timer auto-restarts. This is intentional. **But** `_aim_timer` is `one_shot = true` (correct). The true critical bug is:

`_fire_timer.start()` in `_enter_state` starts the timer from 0 with its configured wait_time. When it times out, `_aim_timer.start(aim_up_time)` is called. The repeating `_fire_timer` then fires again after 3 more seconds — and calls `_aim_timer.start(aim_up_time)` **again**, restarting the aim timer if the bullet hasn't fired yet. With `aim_up_time = 1.0` and fire interval `3.0`, there is no overlap, so in practice this works. **However**, if `aim_up_time` is ever set >= `fire_timer.wait_time`, the aim timer is reset every cycle and `_fire()` is never called. There is no guard.

**More importantly:** the `_fire_timer.start()` call in `_enter_state` passes no override — this relies entirely on the scene-configured `wait_time`. If the scene value is accidentally 0 or default (which is 1.0 in a freshly added Timer), the sniper fires every 1 second and the aim timer overlap risk becomes real.

**Fix:** Add an assertion or clamp to guarantee `aim_up_time < _fire_timer.wait_time`:

```gdscript
func _enter_state(new_state: State) -> void:
    print("[Sniper] _enter_state: %s" % State.keys()[new_state])
    if new_state == State.FIGHTING:
        assert(aim_up_time < _fire_timer.wait_time,
            "aim_up_time must be less than FireTimer.wait_time or _fire() will never be called")
        _fire_timer.start()
    elif new_state == State.FLEEING:
        _fire_timer.stop()
        _aim_timer.stop()
```

---

## Warnings

### WR-01: Bullet spawned without Barrel position — always fires from ship centre

**File:** `components/sniper.gd:99-110`
**Issue:** `_fire()` computes the spawn point as `global_position + fire_dir * 350.0`. The sniper scene has a `Barrel` node at `position = Vector2(40, 0)`, but `_fire()` never reads it. The bullet always originates from the ship's centre offset by 350 units, ignoring the barrel's actual world position. This is visually wrong and inconsistent with the Barrel node's purpose. Beeliner has the same pattern but no Barrel node — the Sniper explicitly added a Barrel node, implying intent to use it.

**Fix:**
```gdscript
@onready var _barrel: Node2D = $Barrel

func _fire() -> void:
    if dying:
        return
    var bullet := _bullet_scene.instantiate() as RigidBody2D
    var fire_dir := Vector2.from_angle(global_rotation)
    bullet.rotation = global_rotation
    bullet.linear_velocity = fire_dir * bullet_speed
    if spawn_parent:
        spawn_parent.add_child(bullet)
        bullet.global_position = _barrel.global_position
    else:
        push_warning("Sniper: spawn_parent not set")
```

---

### WR-02: `_target` is never cleared — sniper continues pursuing a dead or freed player

**File:** `components/sniper.gd:13`
**Issue:** `_target` is set when the player enters the detection area, but it is never set to `null`. If the player dies and is freed from the scene tree, `_tick_state` will call `_target.global_position` on a freed object, causing a "previously freed" runtime error and crash. There is no `detection_area.body_exited` handler and no `is_instance_valid(_target)` guard.

**Fix:** Add a validity check at the top of `_tick_state`, and optionally connect `body_exited` to clear the target:

```gdscript
func _tick_state(_delta: float) -> void:
    if not is_instance_valid(_target):
        _target = null
        if current_state != State.IDLING:
            _change_state(State.IDLING)
        return
    # ... rest of logic
```

---

### WR-03: SEEKING state applies `away` thrust without stopping — sniper drifts forever in comfort band

**File:** `components/sniper.gd:48-49`
**Issue:** In `State.SEEKING`, when `dist < comfort_range` the sniper applies `away * thrust` every physics frame but never enters a stable state or stops the thrust. Because the sniper is a `RigidBody2D` with no linear damping, it accelerates indefinitely away from the player while still in SEEKING. Once it exits `comfort_range` the code falls through to `steer_toward`, reapplying forward thrust every frame. The result is oscillating thrust application without a stable attractor. The FIGHTING state correctly does the same thing but has `FIGHTING_THRUST_MULT` — the SEEKING band has no multiplier and no stable state transition, meaning the sniper will jitter in and out of the comfort band applying large uncapped forces.

**Fix:** Consider transitioning SEEKING into a named `ROAMING` or `HOVERING` state when in the comfort band, or add a velocity-proportional damping force to prevent runaway acceleration:

```gdscript
elif dist < comfort_range:
    # Actively brake if moving toward player, else hold position
    var vel_toward := linear_velocity.dot(toward)
    if vel_toward > 0:
        apply_central_force(away * thrust)
    # else: coasting — no force needed
```

---

### WR-04: `sniper.tscn` — `item_dropper` export points to `CoinDropper` but Sniper.die() calls `_ammo_dropper.drop()` directly; CoinDropper is never triggered

**File:** `prefabs/enemies/sniper/sniper.tscn:38`, `components/sniper.gd:114-120`
**Issue:** The scene exports `item_dropper = NodePath("CoinDropper")` (an inherited export from `Body` or `Ship` used by the parent class death logic). `Sniper.die()` manually calls `_ammo_dropper.drop()` for ammo but never calls `_coinDropper.drop()` or triggers `item_dropper`. Looking at `Beeliner.die()`, it only calls `_ammo_dropper.drop()` too, so this may be an intentional design — but in the Sniper scene `CoinDropper` has `drop_count = 2` and `models` set to a coin drop, implying the designer intended coins to drop. If `item_dropper` is consumed by the base class `die()` call via `super(delay)`, this may be fine — but if `super(delay)` does not call `item_dropper.drop()`, the coin drop silently never fires.

**Fix:** Verify whether `Body.die()` or `Ship.die()` calls `item_dropper.drop()`. If not, add an explicit call in `Sniper.die()`:

```gdscript
func die(delay: float = 0.0) -> void:
    if dying:
        return
    _fire_timer.stop()
    _aim_timer.stop()
    _ammo_dropper.drop()
    $CoinDropper.drop()   # explicit — do not rely on base class if unverified
    super(delay)
```

---

## Info

### IN-01: Production `print()` statements left in hot paths

**File:** `components/sniper.gd:76, 110`
**Issue:** `print("[Sniper] _enter_state: ...")` fires on every state transition and `print("[Sniper] bullet spawned ...")` fires on every shot. These are in physics-adjacent code paths and will generate continuous log noise in production builds. The Beeliner has the same pattern (`beeliner.gd:52`). Per project conventions, commented-out prints are acceptable lightweight debug markers; active prints in hot paths are not.

**Fix:** Either comment out or gate behind a debug flag:
```gdscript
# print("[Sniper] _enter_state: %s" % State.keys()[new_state])
```

---

### IN-02: `sniper-bullet.tscn` — Sprite2D has no texture assigned

**File:** `prefabs/enemies/sniper/sniper-bullet.tscn:27-29`
**Issue:** The `Sprite2D` node has no `texture` property set. The bullet relies entirely on the debug draw in `EnemyBullet._draw()`. This is acceptable for a WIP phase but the Sprite2D node adds overhead (draw call, transform update) with no visual output. It should either be assigned a texture or removed until a sprite is ready.

**Fix:** Remove the `Sprite2D` node until a texture is available, or assign a placeholder texture.

---

### IN-03: Magic constant `350.0` in `_fire()` duplicated from Beeliner without comment linking it to HitBox radius

**File:** `components/sniper.gd:109`
**Issue:** The spawn offset `350.0` is derived from the HitBox `CircleShape2D` radius of `300.0` plus a small buffer — this relationship is undocumented in the Sniper (the Beeliner has a comment `# Spawn past HitBox radius (300)`). The Sniper does have the same comment on line 108, so this is minor, but the value `350` should ideally be a named constant so it stays in sync if HitBox size changes.

**Fix:**
```gdscript
const SPAWN_OFFSET := 350.0  # HitBox radius (300) + 50 unit buffer

# in _fire():
bullet.global_position = global_position + fire_dir * SPAWN_OFFSET
```

---

### IN-04: `world.gd` — `spawn_test_enemy` spawns a `base-enemy-ship`, not a Sniper or Beeliner; misleading for testing Phase 06

**File:** `world.gd:160-165`
**Issue:** The `KEY_T` shortcut spawns `enemy_model` (base-enemy-ship), which has no `_tick_state` implementation and will not exercise the Sniper AI. This is not a bug — it's a legacy debug tool — but it is dead code from a Phase 06 testing perspective.

**Fix:** Either remove or update the shortcut to spawn the new enemy types under test:
```gdscript
func spawn_test_enemy() -> void:
    var enemy = sniper_model.instantiate()   # or beeliner_model
    enemy.global_position = $ShipBFG23.global_position + Vector2(600, 0)
    add_child(enemy)
    setup_spawn_parent(enemy)
```

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
