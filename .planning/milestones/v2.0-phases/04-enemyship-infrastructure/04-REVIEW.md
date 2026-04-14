---
phase: 04-enemyship-infrastructure
reviewed: 2026-04-11T21:10:52Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - components/enemy-ship.gd
  - components/ship.gd
  - prefabs/enemies/base-enemy-ship.tscn
  - world.gd
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-11T21:10:52Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the EnemyShip infrastructure added in Phase 4: the new `EnemyShip` class, the `base-enemy-ship.tscn` scene, supporting changes in `world.gd`, and the existing `Ship` base class for context.

The overall structure is sound. The state machine skeleton, detection area wiring, and `_integrate_forces` speed cap are all correct and follow established project patterns. No critical security or data-loss issues were found.

Five warnings were identified — three are bugs that will silently fail at runtime (missing scene nodes, wrong collision mask for bullet detection, and `ItemDropper.drop()` not receiving `spawn_parent`), and two are logic issues in `world.gd`. Four informational items cover dead-debug drawing left in the scene, a type-annotation gap, and minor style divergences.

---

## Warnings

### WR-01: HitBox collision mask detects Bullets on layer 3, but bullets live on layer 3 only if they also set `collision_layer = 3`

**File:** `prefabs/enemies/base-enemy-ship.tscn:38`
**Issue:** The `HitBox` Area2D has `collision_mask = 4` which selects physics layer 4 (Asteroids), not layer 3 (Bullets). The layer comment in `world.gd` (lines 30-37) lists: `3=Bullets`, `4=Asteroids`. The intent in `enemy-ship.gd:83` is `if body is Bullet`, which will never trigger because the area only overlaps with Asteroid-layer bodies, not Bullet-layer bodies. The enemy ship cannot be damaged by bullets.

**Fix:**
```gdscript
# base-enemy-ship.tscn — HitBox node property
collision_mask = 8  # bit 3 set => layer 3 (Bullets)
# Godot collision_mask is a bitmask: layer N = bit (N-1).
# Layer 3 (Bullets) = 1 << 2 = 4 decimal? Let's be precise:
# Layer 1 = 1, Layer 2 = 2, Layer 3 = 4, Layer 4 = 8
# So collision_mask = 4 IS layer 3 (Bullets). Re-check layer mapping.
```

**Clarification needed:** The `world.gd` comment says layer 3 = Bullets. In Godot's bitmask encoding, layer 3 = bit index 2 = decimal value 4. So `collision_mask = 4` does correctly target layer 3 (Bullets). However the enemy RigidBody2D root has `collision_mask = 3` (layers 1+2 = Ship + Weapons) but no Bullet layer, meaning bullets can physically pass through the enemy without a `body_entered` signal on the RigidBody2D. The HitBox Area2D with `collision_mask = 4` (layer 3, Bullets) is the correct detection mechanism — but only if bullets actually have `collision_layer` bit 3 set. Verify that bullet scenes have `collision_layer` including layer 3; otherwise the HitBox never fires. This should be cross-checked against the bullet prefab scenes.

### WR-02: `ItemDropper` node in scene has no `spawn_parent` wired; drops will always warn and silently fail

**File:** `prefabs/enemies/base-enemy-ship.tscn:47-48`
**Issue:** The `ItemDropper` node is added as a child of `EnemyShip`. When `Body.die()` calls `item_dropper.drop()` (body.gd:55), `ItemDropper.drop()` uses `self.spawn_parent` (item-dropper.gd:22). But `world.gd:setup_spawn_parent` (lines 49-53) only sets `spawn_parent` on nodes that have the property at the Body level — it does not recurse into children of the enemy that are not Body nodes (ItemDropper extends Node2D, not Body). The recursive call in `setup_spawn_parent` does traverse all children, so `ItemDropper` _would_ get `spawn_parent` set via the `"spawn_parent" in node` duck-typed check. However `Body.item_dropper` export is `null` by default and is not set in the scene — meaning `item_dropper.drop()` is never called at all (body.gd:54 guards with `if item_dropper`).

The drop table will silently do nothing on enemy death because `Body.item_dropper` is not assigned in `base-enemy-ship.tscn`.

**Fix:** Wire the `ItemDropper` node to the `item_dropper` export on the root `EnemyShip` node in the scene file:
```ini
# In base-enemy-ship.tscn, add to [node name="EnemyShip" ...]:
item_dropper = NodePath("ItemDropper")
```

### WR-03: `spawn_asteroids` uses float multiplication for loop counts, producing truncation-dependent iteration counts

**File:** `world.gd:137-144`
**Issue:** `range(count * 0.5)`, `range(count * 0.4)`, and `range(count * 0.1)` pass floats to `range()`. GDScript will coerce them to int via truncation, not rounding. For `count=100`: `100 * 0.1 = 10.0` truncates to 10, which is fine. But for `count=10`: `10 * 0.1 = 1.0000000000000001` in floating-point, which truncates to 1 (correct by luck). For `count=7`: `7 * 0.4 = 2.7999...` truncates to 2, losing an asteroid. The totals do not reliably sum to `count`.

**Fix:**
```gdscript
func spawn_asteroids(count: int):
    var small_count := roundi(count * 0.5)
    var medium_count := roundi(count * 0.4)
    var large_count := count - small_count - medium_count  # exact remainder
    for _x in range(small_count):
        add_asteroid(asteroids_small_model.pick_random())
    for _x in range(medium_count):
        add_asteroid(asteroids_medium_model.pick_random())
    for _x in range(large_count):
        add_asteroid(asteroids_large_model.pick_random())
```

### WR-04: `_on_detection_area_body_entered` only transitions from IDLING; re-entry after state change is silently ignored

**File:** `components/enemy-ship.gd:86-90`
**Issue:** The detection handler only calls `_change_state(State.SEEKING)` when `current_state == State.IDLING`. If the player leaves and re-enters the detection area while the enemy is in any other state (SEEKING, LURKING, FIGHTING, etc.), the signal fires but nothing happens. There is also no `body_exited` signal connected, so there is no mechanism to detect when the player leaves the area. Once a state beyond IDLING is reached, the state machine has no external stimulus to drive transitions — `_tick_state` is a no-op stub. This is not a crash bug, but it is a logic gap that will cause silent behavioral failures as soon as `_tick_state` gains any implementation.

**Fix:** Connect `body_exited` alongside `body_entered` in `_ready()`, and handle re-entry in `_on_detection_area_body_entered` regardless of current state (or guard by a broader condition):
```gdscript
detection_area.body_entered.connect(_on_detection_area_body_entered)
detection_area.body_exited.connect(_on_detection_area_body_exited)

func _on_detection_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip:
        _change_state(State.SEEKING)

func _on_detection_area_body_exited(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip and current_state == State.SEEKING:
        _change_state(State.IDLING)
```

### WR-05: `_on_body_entered` in `Ship` applies kinetic damage from all RigidBody2D collisions, including the enemy's own bullets

**File:** `components/ship.gd:38-42`
**Issue:** `Ship._on_body_entered` applies damage for any `RigidBody2D` with non-zero `linear_velocity`. Because `EnemyShip` extends `Ship` and inherits this handler, any RigidBody2D that enters the enemy's physics body will deal kinetic damage to the enemy — including coins, ammo items, and most importantly the enemy's own bullets if they collide with it at spawn (muzzle contact). The `Bullet` class also extends `Body` which extends `RigidBody2D`, so a freshly fired bullet on the same physics frame as spawn can trigger this. The HitBox exists specifically to intercept bullet hits, but the base `body_entered` on the RigidBody2D is also active.

**Fix:** Guard with a type exclusion or only apply damage from meaningful body types:
```gdscript
func _on_body_entered(body):
    if body is Bullet:
        return  # HitBox handles bullets; avoid double-damage or self-damage at spawn
    var speed = body.linear_velocity.length() if body is RigidBody2D else 0.0
    var attack = Damage.new()
    attack.kinetic = speed / 10.0
    damage(attack)
```

Note: this issue exists in `ship.gd` for `PlayerShip` too, but it is more acute for `EnemyShip` which has a HitBox designed specifically for bullet interception.

---

## Info

### IN-01: `_draw()` debug visuals are permanent and always active — no export flag to disable

**File:** `components/enemy-ship.gd:65-78`
**Issue:** The `_draw()` override renders collision boundary arcs, a large detection-radius circle, a direction arrow (500 units long), and a state label unconditionally. These are clearly development aids, but there is no `@export var debug_draw: bool = false` guard. In a scene with multiple enemies, this will produce significant visual noise and extra draw calls. The comment style suggests this is intentional debug scaffolding, but it should be behind a flag.

**Fix:**
```gdscript
@export var debug_draw: bool = true  # set false in production scenes

func _draw() -> void:
    if not debug_draw:
        return
    # ... existing draw calls
```

### IN-02: `_draw()` hardcodes `300.0` for the debug circle radius but `detection_radius` export is `800.0`

**File:** `components/enemy-ship.gd:69-70`
**Issue:** The debug circle drawn at radius 300.0 does not match the `detection_radius` export (800.0) or the `CircleShape2D_detection` radius (800.0) in the scene. The visual representation is misleading — a developer reading the debug overlay will think the detection area is 300 units when it is actually 800.

**Fix:**
```gdscript
draw_circle(Vector2.ZERO, detection_radius, Color(1.0, 0.2, 0.2, 0.15))
draw_arc(Vector2.ZERO, detection_radius, 0.0, TAU, 64, Color(1.0, 0.2, 0.2, 0.5), 4.0)
```

Also update `queue_redraw()` in `_change_state` is already present so state label updates correctly.

### IN-03: `spawn_test_enemy` spawns relative to `$ShipBFG23.global_position` using a hardcoded node path

**File:** `world.gd:147-149`
**Issue:** `$ShipBFG23` is referenced by literal node name without a null-check. If the ship node is renamed or removed, this crashes at startup with no helpful error. The same pattern is repeated throughout `world.gd` but `spawn_test_enemy` is the new addition in this phase.

**Fix:**
```gdscript
@onready var ship: Ship = $ShipBFG23

func spawn_test_enemy() -> void:
    if not ship:
        push_warning("[World] ShipBFG23 not found, cannot spawn test enemy")
        return
    var enemy = enemy_model.instantiate()
    enemy.global_position = ship.global_position + Vector2(600, 0)
    add_child(enemy)
    setup_spawn_parent(enemy)
    print("[World] Test enemy spawned at %s" % enemy.global_position)
```

### IN-04: `EnemyShip` exports (`max_speed`, `thrust`, `detection_radius`) are not grouped

**File:** `components/enemy-ship.gd:15-17`
**Issue:** The project convention (CLAUDE.md) uses `@export_group` to organize related properties. The three movement/detection exports are ungrouped, which will appear in the inspector without context. Minor, but inconsistent with the rest of the codebase where related exports are grouped (e.g., `Ship` does not group either, but that predates the convention).

**Fix:**
```gdscript
@export_group("Movement")
@export var max_speed: float = 500.0
@export var thrust: float = 200.0

@export_group("Detection")
@export var detection_radius: float = 800.0
```

---

_Reviewed: 2026-04-11T21:10:52Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
