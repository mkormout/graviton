<!-- GSD:project-start source:PROJECT.md -->
## Project

**Graviton**

A 2D space shooter built in Godot 4, featuring a component-based ship architecture with hot-swappable weapon mounts, an inventory system, and procedurally scattered asteroids. The player pilots a ship, equips weapons from inventory, and destroys asteroids and (eventually) enemy ships.

**Core Value:** The mount-and-weapon system must work reliably — ships can equip, fire, and swap weapons without bugs or silent failures.

### Constraints

- **Engine**: Godot 4 (GDScript) — no C# or other language targets
- **Migration target**: Godot 4.6.2 in Milestone 2
- **Scope**: Bug fixes and stabilization before migration; no new gameplay features in M1
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- GDScript - All game logic (`.gd` files throughout `components/`, `prefabs/`, `world.gd`)
- None detected
## Runtime
- Godot Engine 4.2.1 (confirmed by `project.godot` `config/features=PackedStringArray("4.2", ...)` and CI image `barichello/godot-ci:4.2.1`)
- None - Godot manages all engine dependencies internally; no external package manager
## Frameworks
- Godot 4.2.1 - Game engine; provides scene tree, physics, rendering, audio, input
- None detected
- Godot headless CLI (`godot --headless --export-release`) - Used in CI for all platform builds
- `barichello/godot-ci:4.2.1` Docker image - CI build container
## Key Dependencies
- Godot 4.2.1 engine - entire runtime; no standalone executable without engine export templates
- `RigidBody2D` - Physics-based movement for asteroids and ships (`components/asteroid.gd`, `components/body.gd`)
- `Node2D` - Base node for all 2D game objects
- `AudioStreamPlayer` / `RandomAudioPlayer` - Sound playback (`components/random-audio-player.gd`)
- `Camera2D` - Camera management (`components/body_camera.gd`)
- Godot Physics 2D - Custom gravity configuration (near-zero gravity: `2d/default_gravity=2.08165e-12` for space setting)
- Godot Resource system (`.tres`) - Item definitions for weapons and ammo
## Configuration
- No `.env` files - all configuration is in `project.godot`
- Key settings: 1920x1080 viewport, maximized window (`mode=2`), max 100 FPS, black background
- `project.godot` - Engine project settings
- `export_presets.cfg` - Platform export configurations
## Rendering
- Mobile fallback: `gl_compatibility`
- VRAM compression: ETC2/ASTC enabled for mobile targets
- Max renderable lights: 128 (custom limit)
- Texture formats: BPTC, S3TC, ETC, ETC2
## Platform Requirements
- Godot 4.2.1 editor installed locally
- Export templates for each target platform (managed via CI)
- No external runtime dependencies beyond the exported binary
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- kebab-case for all `.gd` files: `player-ship.gd`, `item-dropper.gd`, `mountable-weapon.gd`
- Exception: two older files use snake_case — `zoom_level.gd`, `body_camera.gd` (inconsistency, not the pattern to follow)
- PascalCase: `PlayerShip`, `MountableWeapon`, `ItemDropper`, `PropellerMovement`
- Always declared with `class_name` at the top of the file
- Class name matches the concept, not necessarily the file name exactly (e.g., `HudDebugPanel` in `hud.gd`)
- snake_case: `pick_coin()`, `apply_shockwave()`, `register_slot()`, `get_body_opposite()`
- Godot lifecycle functions follow convention: `_ready()`, `_process()`, `_physics_process()`, `_input()`
- Private/internal handlers prefixed with `_on_`: `_on_slot_item_adding()`, `_on_slot_item_removing()`
- Slot/event handlers also prefixed with `_slot_`: `_slot_item_adding()`, `_slot_item_removing()`
- snake_case: `max_health`, `reload_timer`, `magazine_current`, `body_opposite`
- Computed properties (via getter) use snake_case same as regular vars:
- `@onready` vars are snake_case: `weapon_front`, `mount_left`, `cooldown_timer`
- SCREAMING_SNAKE_CASE: `MIN_RANGE`, `MAX_RANGE`, `MAX_LINEAR_VELOCITY`
- Present-participle (gerund) naming — describes the event as it is happening:
- Signal parameters use descriptive names with types: `(sender: MountPoint, target: MountPoint)`
- SCREAMING_SNAKE_CASE inside PascalCase enum:
## Scene and Node Naming
- kebab-case with concept-variant pattern: `asteroid-large-1.tscn`, `minigun-bullet-explosion.tscn`
- Sub-components follow `{parent}-{role}.tscn`: `gausscannon-ammo.tscn`, `rpg-item.tscn`, `laser-bullet.tscn`
- PascalCase for structural nodes: `ShipBFG23`, `WeaponFrontDebug`, `MarginContainer`
- kebab-case inside `$"..."` string references: `$"MarginContainer/TextureRect/Slot-weapon-front"`
- Slot node names use kebab-case with index: `Storage-slot-1`, `Ammo-slot-2`, `Drop-slot-1`
- kebab-case matching the weapon/entity name: `gravitygun/`, `ship-bfg-23/`, `laser/`
## Code Style
- `@export` at top of class, before non-exported vars
- Export groups used to organize related properties:
- Return types annotated on most functions: `func has_ammo() -> bool`, `func drop() -> void`
- Parameter types generally annotated: `func damage(attack: Damage)`, `func plug(other: MountPoint)`
- Some older/simpler functions omit types: `func do(_sender: Node2D, action: String, _where: String, _meta = null)`
- Unused parameters prefixed with `_`: `_delta`, `_sender`, `_where`, `_at_position`
- Classes explicitly state both `class_name` and `extends` on one line:
- Inheritance hierarchy: `Body` → `MountableBody` → `Ship` → `PlayerShip` / `EnemyShip`
- `preload()` used for scenes known at load time, declared as `var` at script top
- `load()` used for dynamic/conditional resource loading (inside `ItemType.init()`)
- Used inline for array filtering and slot iteration:
- Sparse — used for section labels (`# PHYSICAL LAYERS DESCRIPTION:`), intent clarification, or temporarily commented-out debug prints
- Godot auto-generated comments retained in some places: `# Called when the node enters the scene tree for the first time.`
- Commented-out `print()` statements left in place as lightweight debug markers
## Resource and Asset Naming
- kebab-case: `minigun-bullet.png`, `inventory-slot-blue.png`, `laser-item.png`
- Exception: coins use underscore — `coin_copper.png`, `coin_gold.png` (inconsistency)
- kebab-case: `minigun-ammo.tres`, `gravitygun.tres`, `coin-gold.tres`
- Not inspected in detail; directory present
## Scene Organization Pattern
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- All interactive game objects extend `RigidBody2D` via the `Body` class hierarchy
- Weapons, ships, and other mountable bodies are connected through a `MountPoint` plug/unplug system
- No explicit game states or scene transitions — the entire game runs in a single scene (`world.tscn`)
- Physics-based movement with no grid or turn structure; Godot's built-in 2D physics engine drives all collision and impulse behavior
- Gravity is effectively disabled (`2d/default_gravity=2.08165e-12` in `project.godot`) — movement is purely propeller-driven
## Class Hierarchy
```
```
## Core Systems
### 1. Physics and Collision
- All physical bodies are `RigidBody2D` nodes.
- Physics layers (defined in comments in `world.gd`):
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
### Body Death
### Item Pickup
## Key Design Patterns
## Entry Points
- `project.godot`: `run/main_scene = "res://world.tscn"`
- `world.tscn` is the sole scene; no scene transitions exist.
- Mounts three `Minigun` instances onto the ship's three mount points.
- Calls `spawn_asteroids(100)` to populate the world.
- Polls `KEY_SPACE` to fire all weapons each frame.
- Handles all keyboard shortcuts: weapon mounting (1–6), firing (Q/W/E), reload (R), asteroid spawn (Enter), godmode (G), camera toggle (C), inventory toggle (I), weapon unmount (A/S/D).
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
