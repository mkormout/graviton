# Technology Stack: Enemy AI

**Project:** Graviton v2.0 Enemies
**Researched:** 2026-04-11
**Scope:** State-machine enemy AI, simplified fire logic, wave spawning — integrated into existing RigidBody2D ship hierarchy

---

## Recommended Stack

### State Machine Implementation

| Technology | Purpose | Why |
|------------|---------|-----|
| Enum + `match` (inline, single-file) | States for simple enemies (Beeliner, Suicider) | Zero overhead, readable, idiomatic for enemies with 2-3 states |
| Node-based StateMachine + State children | States for complex enemies (Flanker, Sniper, Swarmer) | Isolates per-state logic into separate nodes; each state's `physics_update()` is called by the machine; avoids a giant `match` block |
| GDScript `class_name State extends Node` | Base class for all states | Gives `enter()`, `exit()`, `physics_update(delta)` hooks; states reference `owner` (the EnemyShip) for all character properties |

**Verdict: Use node-based StateMachine as the default.** The project already has 8 planned states and 5 enemy types. A flat enum-per-enemy would duplicate the 8-branch `match` tree in every concrete class. Node-based keeps each state file small, introspectable in the editor, and independently testable.

**Pattern (verified: GDQuest, multiple community tutorials):**

```gdscript
# state.gd
class_name State
extends Node

signal finished(next_state_path: String)

func enter() -> void: pass
func exit() -> void: pass
func physics_update(_delta: float) -> void: pass

# state_machine.gd
class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State

func _ready() -> void:
    for child in get_children():
        if child is State:
            child.state_machine = self
    current_state = initial_state
    current_state.enter()

func transition_to(target_state_path: String) -> void:
    if current_state.name == target_state_path:
        return
    current_state.exit()
    current_state = get_node(target_state_path)
    current_state.enter()

func _physics_process(delta: float) -> void:
    current_state.physics_update(delta)
```

States access the owning EnemyShip via `owner` (the root node of the scene). Store all tunable values (`chase_range`, `fire_range`, `max_speed`) as `@export` vars on EnemyShip, not inside states.

Do NOT mutate the scene tree (add/remove nodes) inside `_physics_process`. Use `call_deferred` if a state needs to do so.

---

### Movement: Steering Behaviors over apply_force

| Technology | Purpose | Why |
|------------|---------|-----|
| `apply_central_force()` on `RigidBody2D` | Seek / flee / arrive per physics frame | Matches how PropellerMovement already drives the player ship — consistent with existing architecture |
| Steering formulas (seek, flee, arrive) | Translate AI intent to physics forces | Pure vector math; no external library needed for 5 enemy types |

NavigationAgent2D is explicitly NOT recommended for this project. Reasons:

1. NavigationAgent2D requires a baked `NavigationRegion2D` covering the map. Graviton's world is unbounded open space (100,000×100,000 background). There is no navigable polygon, no tilemap, no walls. Setting up a nav mesh for open space adds complexity with no benefit.
2. NavigationAgent2D is designed for CharacterBody2D workflows (move_and_slide). With RigidBody2D you would compute the next-path-point and then translate it to an apply_force call yourself — the agent only saves the pathfinding step, which isn't needed in open space.
3. Godot 4.5 introduced a regression in NavigationRegion2D (issue #110686: "more than 2 edges tried to occupy the same map rasterization space") that was targeted for 4.6 but had incomplete fixes. Avoiding NavigationAgent2D eliminates this risk entirely.

**Steering formulas to implement directly:**

```gdscript
# Seek: accelerate toward target
func seek(target_pos: Vector2, max_speed: float, max_force: float) -> void:
    var desired = (target_pos - global_position).normalized() * max_speed
    var steering = desired - linear_velocity
    apply_central_force(steering.limit_length(max_force))

# Flee: same but reversed direction
func flee(threat_pos: Vector2, max_speed: float, max_force: float) -> void:
    var desired = (global_position - threat_pos).normalized() * max_speed
    var steering = desired - linear_velocity
    apply_central_force(steering.limit_length(max_force))

# Arrive: seek with deceleration radius
func arrive(target_pos: Vector2, slow_radius: float, max_speed: float, max_force: float) -> void:
    var to_target = target_pos - global_position
    var dist = to_target.length()
    var speed = max_speed if dist > slow_radius else max_speed * (dist / slow_radius)
    var desired = to_target.normalized() * speed
    var steering = desired - linear_velocity
    apply_central_force(steering.limit_length(max_force))
```

Call these inside each state's `physics_update(delta)`. The `max_speed` limit is enforced by setting `max_linear_velocity` on the RigidBody2D in the scene (same constant pattern as player ship).

---

### Detection: Area2D + RayCast2D

| Node | Purpose | Why |
|------|---------|-----|
| `Area2D` (child of EnemyShip) | Range detection — when player enters seek/fight radius | Body-entered signal; no per-frame polling; clean signal-driven state transitions |
| `CollisionShape2D` (CircleShape2D on the Area2D) | Defines detection radius | Tunable per enemy type via `@export var detection_radius` |
| `PhysicsRayQueryParameters2D` + `PhysicsDirectSpaceState2D` | Line-of-sight check for Sniper | Scriptable raycast (no node needed); use `get_world_2d().direct_space_state.intersect_ray(params)` |

**Pattern: Area2D for range, raycast for LoS.**

The Area2D `body_entered` signal triggers a state transition (e.g., idle → seeking). Inside the seeking/fighting state, optionally verify line-of-sight with a one-off raycast before firing. This avoids polling every physics frame for all enemies when most are far from the player.

Assign the detection Area2D to its own physics layer (not the ship body layer) to avoid triggering collision damage on overlap.

---

### Fire Logic: Inline Timer, No MountableWeapon

| Technology | Purpose | Why |
|------------|---------|-----|
| `Timer` node (one_shot, created in `_ready()`) | Fire rate cooldown | Same pattern as existing MountableWeapon.shot_timer — proven, idiomatic |
| `PackedScene` instantiated at a barrel `Node2D` | Spawn bullet | Reuses existing Bullet class and Damage resource — no new pipeline |

The project decision to skip MountableWeapon/inventory for enemies is correct. The full weapon system carries magazine tracking, reload sounds, ammo inventory, recoil, and mount point synchronization — none of which enemy AI needs. A minimal fire method on EnemyShip (or in a fighting state) creates a bullet at a barrel position, sets its velocity, and starts the cooldown timer.

```gdscript
# Inside EnemyShip or a FightingState
func fire() -> void:
    if not _fire_timer.is_stopped():
        return
    var bullet = bullet_scene.instantiate() as RigidBody2D
    bullet.position = barrel.global_position
    bullet.rotation = global_rotation
    bullet.apply_central_impulse(Vector2.from_angle(global_rotation) * bullet_speed)
    if "spawn_parent" in bullet:
        bullet.spawn_parent = spawn_parent
    spawn_parent.call_deferred("add_child", bullet)
    _fire_timer.start(fire_rate)
```

The existing `Bullet` class and `Damage` resource work without modification. Enemy bullets hit the player ship because `body_entered` on Bullet checks `if body is Body` — the player ship already extends Body.

---

### Wave Spawning

| Technology | Purpose | Why |
|------------|---------|-----|
| `Node` script (`WaveSpawner`) in `world.tscn` | Manage wave state and spawn timing | World already owns asteroid spawning; consistent pattern |
| `Timer` node (repeating) | Delay between wave triggers | Built-in; no polling |
| `@export var spawn_parent: Node` | Scene tree stability for spawned enemies | Same pattern as Body.spawn_parent, already validated in v1.0 (KEY-03) |
| `PackedScene` array per wave | Enemy variety | One entry per enemy type; wave config is a simple Array or Resource |

No plugin needed. The project opted out of GUT and explicitly defers flocking/Boids to v2.1+. LimboAI (behavior trees) is explicitly NOT recommended: it's a C++ GDExtension plugin, supports Godot 4.4-4.5 (not yet confirmed for 4.6.2), and adds a non-trivial dependency for a problem that node-based state machines solve cleanly.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| State machine style | Node-based StateMachine + State nodes | Flat enum + `match` per class | 8 states × 5 enemy types = massive duplication; harder to add states later |
| State machine style | Node-based (no plugin) | LimboAI plugin | C++ GDExtension; Godot 4.6.2 support unconfirmed; adds external dependency for a problem GDScript solves cleanly |
| Pathfinding | Steering forces (seek/flee/arrive) | NavigationAgent2D | Requires NavigationRegion2D bake; broken in 4.5, partially fixed in 4.6; open space world has no nav mesh |
| Fire logic | Inline Timer + PackedScene | Reuse MountableWeapon | MountableWeapon carries inventory, reload, sound, mount sync — overengineered for AI enemies |
| Detection | Area2D signal + optional raycast | Poll `global_position.distance_to` every frame | Signals are event-driven; polling scales poorly with many enemies |

---

## Godot 4.6.2 Specific Notes

- **NavigationAgent2D regression (issue #110686):** Broke in 4.5 due to independent 2D/3D navigation split; targeted for fix in 4.6 but user reports indicate partial resolution only. Avoid entirely — moot since open-space world has no nav mesh.
- **Timer pattern unchanged:** `Timer.new()`, `one_shot`, `timeout.connect(fn, CONNECT_ONE_SHOT)` all work identically to 4.2.1. The MountableWeapon pattern already uses this and survived the 4.6.2 migration.
- **RigidBody2D.apply_central_force:** Present and stable across 4.x. Use in `_physics_process` (or `physics_update` called from there). Using `apply_force` with an offset is also valid for torque effects.
- **`call_deferred("add_child", ...)` for spawning:** Required when instantiating nodes during a physics frame. The existing codebase already uses this correctly in MountableWeapon.fire() and Body.add_successor() — carry the same pattern to enemy fire and spawner.
- **`owner` vs `get_parent()`:** In node-based state machines, states access the character through `owner` (the scene root), not `get_parent()` (which would be the StateMachine node). This requires the StateMachine to be a child of EnemyShip in the scene, and EnemyShip to be the scene root. Confirm scene structure before coding states.
- **Collision layer assignment:** Enemy detection Area2D must be on a different physics layer from ship bodies to avoid triggering `_on_body_entered` collision damage when enemies overlap.

---

## Integration Points with Existing Architecture

| Existing System | Integration Point | What Enemy AI Uses |
|----------------|-------------------|--------------------|
| `Body` / `RigidBody2D` | EnemyShip extends Ship extends Body | `damage()`, `die()`, `item_dropper.drop()`, `spawn_parent` — inherited free |
| `Bullet` + `Damage` resource | Enemy fire spawns existing Bullet scenes | No change to Bullet; enemy fires same ammo types or new lightweight bullet |
| `Body._on_body_entered` | Ships already take kinetic damage on collision | Suicider enemy dies on contact via this existing path + `die()` call |
| `PropellerMovement` | Enemy ships do NOT use PropellerMovement | Movement is driven by state machine steering forces directly — no Input.is_action_pressed |
| `spawn_parent` propagation | Enemies set spawn_parent at instantiation | Follow same `_propagate_spawn_parent` pattern already in Body |
| Physics layers | Comment block in world.gd documents all layers | Assign enemy detection Area2D to an unused layer; verify before using |

---

## Sources

- GDQuest Finite State Machine tutorial: https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/
- Godot 4 NavigationAgent2D 4.5 regression: https://github.com/godotengine/godot/issues/110686
- Steering behaviors for Godot 4 (RigidBody2D): https://www.slashskill.com/steering-behaviors-for-game-ai-avoidance-and-anti-oscillation-in-godot-4/
- Godot 4 Enemy AI state machine: https://codingquests.io/blog/godot-4-enemy-ai-tutorial
- LimboAI plugin (considered, rejected): https://godotengine.org/asset-library/asset/3787
- Godot 4 steering AI framework (considered, overkill): https://github.com/GDQuest/godot-steering-ai-framework
- Godot interactive changelog: https://godotengine.github.io/godot-interactive-changelog/
