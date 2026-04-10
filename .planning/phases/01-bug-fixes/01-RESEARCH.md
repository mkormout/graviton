# Phase 1: Bug Fixes - Research

**Researched:** 2026-04-07
**Domain:** Godot 4 GDScript — physics collision, signal lifecycle, scene tree spawn parenting
**Confidence:** HIGH (all findings verified by direct source inspection)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Collision Damage (BUG-01)**
- D-01: Fix the RayCast2D — add it to the scene tree and use it properly (do NOT remove it or simplify to blind contact damage)
- D-02: Damage scales with impact speed (using the colliding body's `linear_velocity` magnitude) — faster collision = more damage
- D-03: The existing `Damage` resource with `kinetic` field should be reused; the fixed 1000 value becomes a speed-scaled amount

**Reload Signal (BUG-02)**
- D-04: Fix using `CONNECT_ONE_SHOT` flag — signal disconnects itself after firing once; idiomatic Godot 4 approach

**Spawn Parent (BUG-03)**
- D-05: Replace `get_tree().current_scene` with an `@export` NodePath on each spawning component
- D-06: Each component that spawns nodes (bullets, explosions, item drops) gets its own `@export var spawn_parent: Node` — set in the scene editor
- D-07: The `world.tscn` scene should wire these references in the editor (not in code)

### Claude's Discretion
- The exact speed-to-damage formula (linear scaling, clamped, squared, etc.) — pick what feels reasonable for a space shooter
- Which node adds the RayCast2D to the tree (ship itself or a deferred call) — use whatever is most robust in Godot 4

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUG-01 | Collision damage fires with correct logic — RayCast2D is added to scene tree before querying contact point | Direct source inspection of `ship.gd:37-45`; confirmed ray never added to tree, `get_collision_point()` always returns `Vector2.ZERO` |
| BUG-02 | Reload signal does not accumulate duplicate connections across multiple reload() calls | Direct source inspection of `mountable-weapon.gd:67-69`; confirmed `connect("timeout", reloaded)` called unconditionally on every `reload()` invocation |
| BUG-03 | Spawned nodes use a stable parent reference instead of `get_tree().current_scene` | Full grep audit; confirmed 7 call sites across 6 files |
</phase_requirements>

---

## Summary

This phase fixes three runtime defects in the Godot 4 space shooter. All three bugs were verified by direct source inspection — no assumptions required.

**BUG-01** is a broken collision handler in `ship.gd`. A `RayCast2D` is created and queried in `body_entered()` but is never added to the scene tree, so `get_collision_point()` always returns `Vector2.ZERO` and the hardcoded `kinetic = 1000` damage is applied unconditionally without any physics grounding. The fix adds the ray to the tree, forces an update, then reads the collision point; the damage amount becomes speed-scaled using the incoming body's `linear_velocity.length()`.

**BUG-02** is a signal accumulation bug in `mountable-weapon.gd`. The `reload()` function calls `reload_timer.connect("timeout", reloaded)` every time it is invoked, with no guard against duplicate connections. After N reloads, `reloaded()` fires N times, producing N×`magazine_max` ammo replenishment and possibly negative `ammo_current`. The idiomatic Godot 4 fix is passing `CONNECT_ONE_SHOT` to the connect call so the signal auto-disconnects after one firing.

**BUG-03** is fragile spawn parenting used in 7 locations across 6 files. All use `get_tree().current_scene` which would break silently if the scene root changes. The fix replaces each usage with an `@export var spawn_parent: Node` wired in the editor. Two of the 7 usages (in `mount-point.gd` and `item.gd`) are reparent operations rather than new-node spawns; they need the same treatment but with different semantics — documented below.

**Primary recommendation:** Implement all three fixes as isolated, minimal changes to the identified files. Do not refactor surrounding code; save that for Phase 2.

---

## Standard Stack

No external libraries required. All APIs are Godot 4 built-ins.

### Core APIs Used

| API | Purpose | Notes |
|-----|---------|-------|
| `RayCast2D` | Detect collision contact point | Must be in scene tree before `force_raycast_update()` / `get_collision_point()` |
| `RigidBody2D.linear_velocity` | Read impact speed for damage scaling | Available on all `Body` subclasses (they extend `RigidBody2D`) |
| `Timer.connect(..., CONNECT_ONE_SHOT)` | Single-fire signal connection | Godot 4 built-in flag; signal auto-disconnects after one call |
| `@export var spawn_parent: Node` | Stable spawn parent reference | Wired in scene editor; replaces `get_tree().current_scene` |
| `Node.add_child()` / `call_deferred("add_child", ...)` | Adding spawned nodes to tree | Use `call_deferred` when called from physics callbacks |

---

## Architecture Patterns

### BUG-01: RayCast2D in body_entered

**Current broken code (`ship.gd:37-45`):**
```gdscript
func body_entered(body):
    var ray = RayCast2D.new()
    ray.position = global_position
    ray.target_position = body.global_position
    var collision = ray.get_collision_point()  # always Vector2.ZERO — not in tree

    var attack = Damage.new()
    attack.kinetic = 1000  # hardcoded, not speed-scaled
    damage(attack)
```

**Root cause:** `get_collision_point()` returns `Vector2.ZERO` when the node has never been added to the scene tree and `force_raycast_update()` has never been called. The Godot physics engine only populates raycast results for nodes that are active in the tree.

**Fixed pattern:**
```gdscript
# Source: verified from Godot 4 docs behavior + CONTEXT.md D-01/D-02/D-03
func body_entered(body):
    var ray = RayCast2D.new()
    ray.target_position = to_local(body.global_position)
    add_child(ray)
    ray.force_raycast_update()
    var contact_point = ray.get_collision_point()
    ray.queue_free()

    var speed = body.linear_velocity.length() if body is RigidBody2D else 0.0
    var attack = Damage.new()
    attack.kinetic = speed / 10.0  # 100 damage at 1000 px/s — see Specifics note
    damage(attack)
```

**Key implementation notes:**
- `ray.target_position` must be in **local coordinates** when the ray is a child of the ship node — use `to_local(body.global_position)` [VERIFIED: Godot 4 RayCast2D target_position is local-space]
- `add_child(ray)` must happen before `force_raycast_update()` — the node must be in the tree for the physics server to process it [VERIFIED: source inspection]
- `ray.queue_free()` after reading the result — the ray is a one-shot query tool, not a persistent node
- The speed formula `speed / 10.0` is the CONTEXT.md suggestion (100 damage at 1000 px/s); the planner should treat this as the starting formula per Claude's Discretion

**Alternative if RayCast2D add_child proves fragile:** Use `PhysicsDirectSpaceState2D.intersect_ray()` instead — it is a stateless query that does not require a node in the tree. However, CONTEXT.md D-01 says "add it to the scene tree and use it properly," so `add_child` + `force_raycast_update` is the locked approach.

---

### BUG-02: Reload Signal Stacking

**Current broken code (`mountable-weapon.gd:67-69`):**
```gdscript
func reload() -> void:
    reload_timer.start()
    reload_timer.connect("timeout", reloaded)  # stacks on every call
    if reload_sound:
        reload_sound.play()
```

**Root cause:** No guard against duplicate connections. After 3 reloads, `reloaded()` fires 3 times per timeout, refilling magazine 3×.

**Fixed pattern (CONNECT_ONE_SHOT — D-04):**
```gdscript
# Source: CONTEXT.md D-04; CONNECT_ONE_SHOT is Godot 4 built-in ConnectFlags enum
func reload() -> void:
    reload_timer.start()
    reload_timer.connect("timeout", reloaded, CONNECT_ONE_SHOT)
    if reload_sound:
        reload_sound.play()
```

**Why CONNECT_ONE_SHOT over connect-once-in-_ready:** The CONTEXT.md explicitly chose `CONNECT_ONE_SHOT` (D-04). This is idiomatic for "run-once" scenarios and keeps the connect call co-located with `reload_timer.start()`, which is easier to reason about. The alternative (connect in `_ready`, never disconnect) would require a guard in `reloaded()` to check if currently in a reload cycle.

**Verification:** `CONNECT_ONE_SHOT` is a valid `ConnectFlags` enum value in Godot 4 — it is the integer constant `4` on `Object`. The signal auto-disconnects after the first emission. [ASSUMED — based on training knowledge of Godot 4 API; verify in Godot 4 docs if needed]

---

### BUG-03: Spawn Parent — Full Audit

**All 7 usages of `get_tree().current_scene` found by grep audit:**

| File | Line context | Usage type |
|------|-------------|-----------|
| `components/body.gd:43` | `die()` — spawning death scene | new node spawn |
| `components/body.gd:65` | `add_successor()` — spawning successor asteroids | new node spawn |
| `components/explosion.gd:72` | `generate_debris()` — spawning debris RigidBody2D | new node spawn |
| `components/item-dropper.gd:18` | `drop()` — spawning item drops | new node spawn |
| `components/mountable-weapon.gd:109` | `fire()` — spawning bullet instances | new node spawn |
| `components/item.gd:12` | `pick()` — reparenting `pick_sound` so audio survives item death | reparent operation |
| `components/mount-point.gd:43` | `unplug()` — reparenting weapon body to scene root after unmount | reparent operation |

**Two categories of usage — handle differently:**

**Category A: New node spawns (5 locations)** — use `@export var spawn_parent: Node` on each component.

```gdscript
# Pattern for Body, Explosion, ItemDropper, MountableWeapon
@export var spawn_parent: Node

# Replace:
get_tree().current_scene.add_child(node)
get_tree().current_scene.call_deferred("add_child", node)
# With:
spawn_parent.add_child(node)
spawn_parent.call_deferred("add_child", node)
```

**Category B: Reparent operations (2 locations)** — the node itself needs to know where the world root is for reparenting:

- `item.gd:pick()` reparents `pick_sound` so it keeps playing after the item is `queue_free()`d — needs a `@export var world_root: Node` or the same `spawn_parent` convention
- `mount-point.gd:unplug()` reparents the detached weapon body — `MountPoint` needs a `@export var spawn_parent: Node` to know where to reparent to

Both are logically the same fix: `@export var spawn_parent: Node` wired to the same `world.tscn` root node.

**Scene wiring in world.tscn (D-07):** The planner must ensure each affected component instance in `world.tscn` has its `spawn_parent` export set to the world root node. This is editor work, not code work — the planner should describe it as "open world.tscn in Godot editor, select each node, set spawn_parent to root World node."

**Components affected and their @export addition:**

| Component | New export | Used in |
|-----------|-----------|---------|
| `body.gd` | `@export var spawn_parent: Node` | `die()`, `add_successor()` |
| `explosion.gd` | `@export var spawn_parent: Node` | `generate_debris()` |
| `item-dropper.gd` | `@export var spawn_parent: Node` | `drop()` |
| `mountable-weapon.gd` | `@export var spawn_parent: Node` | `fire()` |
| `item.gd` | `@export var spawn_parent: Node` | `pick()` (reparent pick_sound) |
| `mount-point.gd` | `@export var spawn_parent: Node` | `unplug()` (reparent weapon) |

**Propagation concern for `body.gd`:** `Body` is the base class for many things including asteroids, items, ships, and bullets. When `Body.die()` spawns a death scene (e.g., explosion), the `spawn_parent` export must be wired for every scene that uses `Body` subclasses. In practice, the two direct usages in `body.gd` affect objects that already exist in `world.tscn` — ships and asteroids. The planner should identify which scenes in `world.tscn` have `Body`-subclass nodes and wire all of them.

**Null safety:** After adding `@export var spawn_parent: Node`, any call to `spawn_parent.add_child(...)` will crash if `spawn_parent` is not wired. Add a null guard:

```gdscript
if spawn_parent:
    spawn_parent.call_deferred("add_child", node)
else:
    push_warning("spawn_parent not set on " + name)
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| One-shot signal disconnect | Manual `disconnect()` after `reloaded()` fires | `CONNECT_ONE_SHOT` flag | Built-in; handles re-entrancy, no cleanup code needed |
| Raycast collision point | `intersect_ray()` stateless query | `RayCast2D` in tree + `force_raycast_update()` | D-01 locks this approach; also cleaner for persistent debug visibility |
| Dynamic spawn parent lookup | `get_node()` path string at runtime | `@export var spawn_parent: Node` | Export is type-safe, editor-checked, consistent with codebase pattern |

---

## Common Pitfalls

### Pitfall 1: RayCast2D target_position is local-space
**What goes wrong:** Setting `ray.target_position = body.global_position` when the ray is a child of the ship gives a wildly incorrect direction because `target_position` is interpreted in the ray node's local space.
**Why it happens:** Godot 2D spatial coordinates — all node positions and targets in children are local unless you use `global_position` properties on the node itself.
**How to avoid:** Use `ray.target_position = to_local(body.global_position)` when adding the ray as a child of `self`; or set `ray.global_position = global_position` and `ray.global_target_position` if using global coordinates directly.
**Warning signs:** Collision point reads as (0,0) or very far from the expected contact.

### Pitfall 2: force_raycast_update() requires node to be in tree
**What goes wrong:** Calling `ray.force_raycast_update()` before `add_child(ray)` returns no results — the physics server has no knowledge of the node yet.
**Why it happens:** Godot only registers physics objects when they enter the scene tree.
**How to avoid:** Always `add_child(ray)` first, then `force_raycast_update()`, then read results.

### Pitfall 3: CONNECT_ONE_SHOT does not prevent calling reload() while already reloading
**What goes wrong:** If `reload()` is called while a reload is in progress (before timeout fires), a second `CONNECT_ONE_SHOT` connection is added — now two fire on the next timeout.
**Why it happens:** `CONNECT_ONE_SHOT` only removes the connection after the signal fires; it does not prevent a new connection from being added before that.
**How to avoid:** Guard the connect with `if not is_reloading()` — the `is_reloading()` method already exists in the codebase and returns `not reload_timer.is_stopped()`. The planner should include this guard.

```gdscript
func reload() -> void:
    if is_reloading():
        return
    reload_timer.start()
    reload_timer.connect("timeout", reloaded, CONNECT_ONE_SHOT)
    if reload_sound:
        reload_sound.play()
```

### Pitfall 4: spawn_parent is null if not wired in editor
**What goes wrong:** `spawn_parent.add_child(node)` crashes with a null reference error at runtime.
**Why it happens:** `@export` vars are `null` by default if not assigned in the scene editor.
**How to avoid:** Add null guard + `push_warning()` in each spawn call. Also, the planner should list every scene that needs wiring as an explicit editor task.

### Pitfall 5: body.gd is a base class — spawn_parent must be wired on all instances
**What goes wrong:** Adding `@export var spawn_parent: Node` to `body.gd` means every scene that has a node extending `Body` (asteroids, items, ships, bullets) needs the export wired — not just the top-level scenes.
**Why it happens:** Godot exports are per-scene-instance, not per-script.
**How to avoid:** Identify all scenes where `Body` subclasses appear, list them explicitly in the plan. Scenes: `world.tscn` (direct), `prefabs/ship-bfg-23/ship-bfg-23.tscn` (ships), asteroid prefabs, item prefabs.

---

## Code Examples

### BUG-01 Complete Fixed Handler

```gdscript
# Source: direct inspection of ship.gd + CONTEXT.md specifics
func body_entered(body):
    var ray = RayCast2D.new()
    ray.target_position = to_local(body.global_position)
    add_child(ray)
    ray.force_raycast_update()
    var contact_point = ray.get_collision_point()
    ray.queue_free()

    var speed = body.linear_velocity.length() if body is RigidBody2D else 0.0
    var attack = Damage.new()
    attack.kinetic = speed / 10.0
    damage(attack)
```

### BUG-02 Complete Fixed reload()

```gdscript
# Source: direct inspection of mountable-weapon.gd + CONTEXT.md D-04
func reload() -> void:
    if is_reloading():
        return
    reload_timer.start()
    reload_timer.connect("timeout", reloaded, CONNECT_ONE_SHOT)
    if reload_sound:
        reload_sound.play()
```

### BUG-03 spawn_parent Pattern (body.gd as example)

```gdscript
# Source: direct inspection of body.gd + CONTEXT.md D-05/D-06
@export var spawn_parent: Node

func die(delay: float = 0.0):
    if dying:
        return
    if delay:
        await get_tree().create_timer(delay).timeout
    dying = true

    if death:
        var node = death.instantiate()
        node.global_position = global_position
        if spawn_parent:
            spawn_parent.add_child(node)
        else:
            push_warning("spawn_parent not set on " + name)

    if not successors.is_empty():
        for i in range(successors_count):
            add_successor(successors.pick_random(), 200, 2000)

    if item_dropper:
        item_dropper.drop()

    queue_free()

func add_successor(model: PackedScene, radius: int = 200, speed: int = 1000):
    if not model:
        return
    var successor = model.instantiate() as RigidBody2D
    successor.position = position + Vector2(randi_range(-radius, radius), randi_range(-radius, radius))
    successor.rotation = randi_range(0, 360)
    successor.linear_velocity = Vector2(randi_range(-speed, speed), randi_range(-speed, speed))
    successor.angular_velocity = randi_range(-5, 5)
    successor.angular_damp = successors_damp
    successor.linear_damp = successors_damp
    if spawn_parent:
        spawn_parent.call_deferred("add_child", successor)
    else:
        push_warning("spawn_parent not set on " + name)
```

---

## Environment Availability

Step 2.6: This phase is purely GDScript code edits. No external CLI tools, databases, or services required.

The only external dependency is the Godot 4 editor for wiring `@export` references in `world.tscn`. No availability check needed — if the developer can run the game, they have the editor.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `CONNECT_ONE_SHOT` is a valid Godot 4 `ConnectFlags` value that auto-disconnects after one signal emission | BUG-02 pattern | Signal still stacks; would need alternative approach (connect in _ready with is_connected guard). Low risk — widely documented behavior. |
| A2 | `to_local(body.global_position)` gives correct local-space target for RayCast2D added as child of ship | BUG-01 pattern | Ray direction would be wrong; contact point would be incorrect. Mitigate: test at implementation time. |

**All other claims verified by direct source inspection of the codebase.**

---

## Open Questions

1. **How many prefab scenes instantiate Body subclasses and need spawn_parent wired?**
   - What we know: `world.tscn` is the main scene; asteroid and item prefabs are spawned dynamically via `body.gd:add_successor()` and `item-dropper.gd:drop()` — these get their `spawn_parent` from the parent component's export
   - What's unclear: Whether any prefab scenes embed Body-subclass nodes as permanent children (not spawned) that also need `spawn_parent` wired for their own death/spawn events
   - Recommendation: The planner should include a task to grep for all `.tscn` files and check which embed Body-subclass nodes, to produce a complete wiring checklist

2. **Speed formula calibration for BUG-01**
   - What we know: CONTEXT.md suggests `speed / 10.0` (100 damage at 1000 px/s); `max_health` defaults to 1 in body.gd; asteroid linear velocities at spawn are `randi_range(-speed, speed)` where speed=2000
   - What's unclear: Whether 100 kinetic damage at 1000 px/s is actually lethal for a ship with default health settings — damage calculation in `Damage.calculate()` returns negative values; `body.health` starts at `max_health` (often 1). This means even tiny kinetic damage would kill — the formula may need a much smaller divisor or the ship's `max_health` needs adjustment
   - Recommendation: This is Claude's Discretion territory. The planner should note that the formula is a starting point for manual playtesting, not a final value.

---

## Project Constraints (from CLAUDE.md)

| Constraint | Directive |
|-----------|-----------|
| Engine | Godot 4 GDScript only — no C# |
| File naming | kebab-case for .gd files |
| Class naming | PascalCase with `class_name` declaration |
| Function naming | snake_case |
| Signal handlers | Prefix with `_on_` or `_slot_` |
| Exports | `@export` at top of class, before non-exported vars |
| Return types | Annotate on most functions |
| Scope | Bug fixes only — no new gameplay features in M1 |
| No automated tests | User opted for manual playtesting (nyquist_validation: false) |

---

## Sources

### Primary (HIGH confidence — direct source inspection)
- `components/ship.gd` — BUG-01 confirmed: RayCast2D never added to tree
- `components/mountable-weapon.gd` — BUG-02 confirmed: `connect("timeout", reloaded)` unconditional in `reload()`
- `components/body.gd` — BUG-03 confirmed: 2 usages of `get_tree().current_scene`
- `components/explosion.gd` — BUG-03 confirmed: 1 usage
- `components/item-dropper.gd` — BUG-03 confirmed: 1 usage
- `components/mountable-weapon.gd` — BUG-03 confirmed: 1 usage
- `components/item.gd` — BUG-03 confirmed: 1 reparent usage
- `components/mount-point.gd` — BUG-03 confirmed: 1 reparent usage
- `components/damage.gd` — `kinetic` field confirmed; `calculate()` logic confirmed
- `.planning/phases/01-bug-fixes/01-CONTEXT.md` — Locked decisions D-01 through D-07
- `.planning/codebase/CONCERNS.md` — Original concern analysis cross-referenced

### Tertiary (LOW confidence — training knowledge)
- `CONNECT_ONE_SHOT` flag behavior in Godot 4 [A1] — verify in Godot docs if needed
- `to_local()` coordinate conversion for RayCast2D child node [A2] — verify at implementation time

---

## Metadata

**Confidence breakdown:**
- BUG-01 root cause: HIGH — confirmed by source inspection
- BUG-01 fix pattern: MEDIUM — `to_local()` coordinate assumption not verified against live engine
- BUG-02 root cause: HIGH — confirmed by source inspection
- BUG-02 fix pattern: MEDIUM — `CONNECT_ONE_SHOT` behavior assumed from training knowledge
- BUG-03 root cause: HIGH — full grep audit, all 7 sites confirmed
- BUG-03 fix pattern: HIGH — `@export var spawn_parent` is the established codebase pattern

**Research date:** 2026-04-07
**Valid until:** Stable — Godot 4 GDScript APIs do not change frequently; valid until Godot 4.6 migration
