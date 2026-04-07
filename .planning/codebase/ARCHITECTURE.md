# Architecture

**Analysis Date:** 2026-04-07

## Pattern Overview

**Overall:** Component-based, composition-driven 2D physics game (Godot 4.2)

**Key Characteristics:**
- All interactive game objects extend `RigidBody2D` via the `Body` class hierarchy
- Weapons, ships, and other mountable bodies are connected through a `MountPoint` plug/unplug system
- No explicit game states or scene transitions — the entire game runs in a single scene (`world.tscn`)
- Physics-based movement with no grid or turn structure; Godot's built-in 2D physics engine drives all collision and impulse behavior
- Gravity is effectively disabled (`2d/default_gravity=2.08165e-12` in `project.godot`) — movement is purely propeller-driven

## Class Hierarchy

```
RigidBody2D (Godot built-in)
└── Body                          # components/body.gd
    ├── MountableBody             # components/mountable-body.gd
    │   ├── MountableWeapon       # components/mountable-weapon.gd
    │   │   └── GravityGun        # prefabs/gravitygun/gravitygun-script.gd
    │   └── Ship                  # components/ship.gd
    │       ├── PlayerShip        # components/player-ship.gd
    │       └── EnemyShip         # components/enemy-ship.gd
    ├── Bullet                    # components/bullet.gd
    ├── Item                      # components/item.gd
    │   └── Ammo                  # components/ammo.gd
    └── Asteroid                  # components/asteroid.gd

Resource (Godot built-in)
├── Damage                        # components/damage.gd
├── ItemType                      # components/item-type.gd
├── ItemDrop                      # components/item-drop.gd
└── PropellerMovementProfile      # components/propeller-movement-profile.gd

Node (Godot built-in)
├── Inventory                     # components/inventory.gd
├── ItemDropper                   # components/item-dropper.gd
└── PropellerMovement             # components/propeller-movement.gd

Control (Godot built-in)
└── InventorySlot                 # components/inventory-slot.gd

Node2D (Godot built-in)
├── MountPoint                    # components/mount-point.gd
├── ItemDropper                   # components/item-dropper.gd
├── Explosion                     # components/explosion.gd
└── RandomAudioPlayer             # components/random-audio-player.gd

Camera2D (Godot built-in)
└── BodyCamera                    # components/body_camera.gd
```

## Core Systems

### 1. Physics and Collision
- All physical bodies are `RigidBody2D` nodes.
- Physics layers (defined in comments in `world.gd`):
  - Layer 1: Ship
  - Layer 2: Weapons
  - Layer 3: Bullets
  - Layer 4: Asteroids
  - Layer 5: Explosions
  - Layer 6: Coins
  - Layer 7: Ammo
  - Layer 8: Weapon Items
- `Body` (`components/body.gd`) wraps `RigidBody2D` with health, death, and successor-spawning logic.
- Bullets use `body_entered` signals to apply `Damage` on collision.

### 2. Mount Point System
- `MountPoint` (`components/mount-point.gd`) is the connector between bodies.
- Every `MountableBody` can have one or more named `MountPoint` nodes (`""`, `"left"`, `"right"`).
- `plug(other: MountPoint)` connects two bodies; `unplug()` disconnects them and physically launches the detached body.
- `MountableBody._physics_process` continuously syncs the mounted body's `global_position` and `global_rotation` to the mount's position each physics frame.
- Commands are routed through mount points via `do(sender, action, where, meta)` calls — enabling e.g. firing a weapon on a named slot.

### 3. Weapon System
- `MountableWeapon` (`components/mountable-weapon.gd`) extends `MountableBody`.
- Manages firing rate (`shot_timer`), magazine (`magazine_current`), total ammo (`ammo_current`), and reload (`reload_timer`) internally.
- `fire()` instantiates the bullet `PackedScene` at the barrel position, applies a velocity impulse, and optionally sends a recoil impulse back through the `MountPoint` chain to the parent ship.
- Weapons respond to string-based action commands: `"fire"`, `"reload"`, `"godmode"`, `"use_ammo"`, `"use_rate"`.
- `GravityGun` (`prefabs/gravitygun/gravitygun-script.gd`) extends `MountableWeapon`, overriding `fire()` to apply area-based shockwave and damage instead of spawning a projectile.

### 4. Damage System
- `Damage` (`components/damage.gd`) is a `Resource` with `energy` and `kinetic` float fields.
- `Damage.calculate(defense: Damage)` returns net damage: `-(energy + kinetic) + defense.energy + defense.kinetic`, clamped to ≤ 0.
- `Body.damage(attack: Damage)` subtracts from `health` and calls `die()` when health ≤ 0.
- `Explosion` (`components/explosion.gd`) applies distance-falloff damage and shockwave impulses using an `Area2D`.

### 5. Inventory System
- `Inventory` (`components/inventory.gd`) is a `Node` that manages a list of `InventorySlot` nodes.
- `InventorySlot` (`components/inventory-slot.gd`) extends `Control` and tracks `occupant: ItemType` and `quantity`.
- Slots emit `item_adding` / `item_removing` signals picked up by `Inventory` and `MountPoint`.
- `MountPoint` observes linked `InventorySlot` signals to auto-plug/unplug weapons when weapon slots change.
- `InventorySlot` supports drag-and-drop via Godot's `_get_drag_data` / `_drop_data` API.
- Each ship has three `Inventory` nodes: `InventoryStorage`, `InventoryAmmo`, `InventoryDrop`.

### 6. Item and Drop System
- `Item` (`components/item.gd`) is a `Body` with an `ItemType` reference.
- `ItemType` (`components/item-type.gd`) is a `Resource` describing the item (name, type enum, price, image) and can dynamically load and instantiate the matching prefab from `res://prefabs/{name}/{name}.tscn`.
- `ItemDropper` (`components/item-dropper.gd`) is a `Node2D` with a weighted-random drop table (`Array[ItemDrop]`). Called on body death.
- `Ship.picker_body_entered` routes picked-up `Item` nodes to the appropriate inventory based on `ItemType.type` (`COIN`, `AMMO`, `WEAPON`, `HEALTH`).

### 7. Propulsion System
- `PropellerMovement` (`components/propeller-movement.gd`) reads a Godot `InputAction` every physics frame.
- When the action is pressed, it calls `apply_force` on the parent `RigidBody2D` using thrust and direction from a `PropellerMovementProfile` resource.
- Simultaneously toggles `CPUParticles2D` emission and a `PointLight2D` on/off.
- Ship BFG-23 has three propellers: `PropellerMain` (forward, `ui_up`), `PropellerLeft` (`ui_right`), `PropellerRight` (`ui_left`).

### 8. Camera System
- Two cameras exist in `world.tscn`: a static `Camera2D` (wide overview) and a `BodyCamera` attached to the ship.
- `BodyCamera` (`components/body_camera.gd`) extends `Camera2D`, follows `body.global_position` every frame, and dynamically adjusts zoom based on ship speed (faster = more zoomed out).
- Camera is toggled between overview and ship-follow with `KEY_C` in `world.gd`.

### 9. Rendering
- Viewport: 1920×1080, maximized window.
- Background: large `ColorRect` (100,000×100,000 units) at `z_index = -500`.
- Starfield: `CPUParticles2D` with 50,000 particles, fixed 5 FPS, spanning 100,000 units.
- Lighting: `CanvasModulate` dims the scene; `PointLight2D` nodes on the sun and propellers provide dynamic 2D lighting with shadow casting.
- `LightOccluder2D` polygons are present on ships and large asteroids.

## Data Flow

### Firing a Weapon
1. `world.gd._process` detects `KEY_SPACE` → calls `notify_weapons("fire")`.
2. `world.gd` calls `$ShipBFG23.do(null, "fire", "")` (and `"left"`, `"right"`).
3. `MountableBody.do` locates the named `MountPoint` and calls `mount.do(sender, action, meta)`.
4. `MountPoint.do` forwards to the connected mount on the weapon side, which calls `body_self.do(...)`.
5. `MountableWeapon.do` receives `"fire"` and calls `fire()`.
6. `fire()` instantiates the bullet scene, sets position/rotation/velocity, and adds it to `current_scene` via `call_deferred`.
7. Recoil impulse is sent back up the mount chain via `mount.do(self, "recoil", recoil)`.

### Body Death
1. `Body.damage(attack)` reduces `health`. When `health <= 0`, calls `die()`.
2. `die()` sets `dying = true`, instantiates the `death` PackedScene at `global_position`, spawns successors (e.g. a large asteroid splits into medium ones), calls `item_dropper.drop()`, then `queue_free()`.
3. Successors are spawned with random velocity/rotation via `add_successor`.

### Item Pickup
1. `Ship.picker` (`Area2D`) detects `body_entered` for any `Item` in layers 6 and 7.
2. `picker_body_entered` matches `item.type.type` enum to call `pick_coin`, `pick_ammo`, `pick_weapon`, or `pick_health`.
3. The item is added to the appropriate `Inventory`, then `item.pick()` plays pickup audio and calls `Body.die()`.

## Key Design Patterns

**String-based Command Routing:** Weapons and bodies communicate via `do(sender, action, where, meta)` with string action names. This decouples callers from specific weapon implementations.

**Plug/Unplug Composition:** Bodies are assembled at runtime by plugging `MountableWeapon` nodes into `MountPoint` slots. Weapons become physical children of the mount and are fully independent `RigidBody2D` nodes.

**Resource-as-Config:** `ItemType`, `PropellerMovementProfile`, `Damage`, and `ItemDrop` are all `Resource` subclasses — serialized in `.tres` files. This separates data from behavior.

**Successor Spawning:** Large bodies (asteroids) define `successors: Array[PackedScene]` and `successors_count`. On death, `Body` randomly picks and spawns successors, enabling asteroid splitting.

**Weighted Random Drops:** `ItemDropper` uses a cumulative weight table (`ItemDrop.chance`) to select a random drop model, enabling loot variety without hard-coded probabilities.

## Entry Points

**Application Start:**
- `project.godot`: `run/main_scene = "res://world.tscn"`
- `world.tscn` is the sole scene; no scene transitions exist.

**`world.gd._ready()`:**
- Mounts three `Minigun` instances onto the ship's three mount points.
- Calls `spawn_asteroids(100)` to populate the world.

**`world.gd._process(delta)`:**
- Polls `KEY_SPACE` to fire all weapons each frame.

**`world.gd._input(ev)`:**
- Handles all keyboard shortcuts: weapon mounting (1–6), firing (Q/W/E), reload (R), asteroid spawn (Enter), godmode (G), camera toggle (C), inventory toggle (I), weapon unmount (A/S/D).
