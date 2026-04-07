# Codebase Structure

**Analysis Date:** 2026-04-07

## Directory Layout

```
graviton/
├── components/         # Reusable GDScript classes (no scenes, pure logic/class definitions)
├── items/              # ItemType resource (.tres) definitions for all inventory items
├── prefabs/            # Scenes (.tscn) and per-prefab scripts for all instantiable objects
│   ├── asteroid/       # Asteroid scenes (large-1/2, medium-1/2/3, small-1/2/3/4)
│   ├── coin/           # Coin scenes (copper, silver, gold, explosion)
│   ├── gausscannon/    # Gauss cannon weapon, bullet, ammo, item scenes
│   ├── gravitygun/     # Gravity gun weapon, bullet, ammo, item scenes + script
│   ├── laser/          # Laser weapon, bullet, ammo, item scenes
│   ├── minigun/        # Minigun weapon, bullet, ammo, item scenes
│   ├── rpg/            # RPG weapon, bullet, ammo, item scenes
│   ├── ship-bfg-23/    # Player ship scene, inventory scene, explosion scene, propeller profiles
│   └── ui/             # HUD, status bar, controls hint, weapon debug panel, inventory UI
│       └── inventory/  # Inventory slot scenes (storage, weapon, ammo, drop slots)
├── sounds/             # Audio files (.mp3, .wav)
├── images/             # Sprite textures (.png, .svg)
├── .planning/          # GSD planning documents (not game code)
│   └── codebase/       # Codebase analysis documents
├── world.tscn          # Main (and only) game scene
├── world.gd            # Main scene script: spawn, input, world management
├── project.godot       # Godot project configuration
└── icon.svg            # Application icon
```

## Directory Purposes

**`components/`**
- Purpose: Base classes and shared logic used across all prefabs. Scripts only — no `.tscn` files.
- Contains: GDScript files that define `class_name` types
- Key files:
  - `body.gd` — base `RigidBody2D` with health, death, successor spawning
  - `mountable-body.gd` — body that can host `MountPoint` nodes and relay commands
  - `mountable-weapon.gd` — fire/reload/ammo logic for all weapons
  - `mount-point.gd` — plug/unplug connector between bodies; links inventory slots
  - `ship.gd` — ship picking logic (coins, weapons, ammo, health)
  - `player-ship.gd` — `PlayerShip` class (currently just extends `Ship`)
  - `enemy-ship.gd` — `EnemyShip` class (currently just extends `Ship`)
  - `bullet.gd` — timed projectile with collision damage
  - `explosion.gd` — area damage, shockwave, debris on spawn
  - `damage.gd` — `Damage` resource with energy/kinetic fields and calculation
  - `inventory.gd` — slot registry and item routing
  - `inventory-slot.gd` — single inventory cell with drag-and-drop
  - `item.gd` — physics-based pickable with type reference
  - `item-type.gd` — `Resource` describing an item class; lazy-loads its prefab
  - `item-dropper.gd` — weighted random loot table node
  - `item-drop.gd` — single entry in a drop table (model + chance)
  - `propeller-movement.gd` — input-driven thrust force applicator
  - `propeller-movement-profile.gd` — thrust + direction resource
  - `body_camera.gd` — speed-adaptive follow camera
  - `random-audio-player.gd` — plays a random `AudioStream` from a list
  - `zoom_level.gd` — data class for camera zoom thresholds
  - `asteroid.gd` — `Asteroid` class (extends `Body`, currently no extra logic)
  - `ammo.gd` — `Ammo` class (extends `Item` with an `amount` field)

**`items/`**
- Purpose: `.tres` resource files, each an instance of `ItemType`. One file per game item.
- Contains: `coin-copper.tres`, `coin-gold.tres`, `coin-silver.tres`, `gausscannon-ammo.tres`, `gausscannon.tres`, `gravitygun-ammo.tres`, `gravitygun.tres`, `laser-ammo.tres`, `laser.tres`, `minigun-ammo.tres`, `minigun.tres`, `rpg-ammo.tres`, `rpg.tres`
- Key pattern: Each `.tres` sets `name` (maps to prefab folder/file name), `type` (enum), `price`, and `image`.

**`prefabs/`**
- Purpose: All instantiable Godot scenes and any scene-specific scripts.
- Naming convention: `{object}/{object}.tscn` for the main scene, `{object}/{object}-{variant}.tscn` for bullets, ammo, items, explosions.

**`prefabs/asteroid/`**
- Nine asteroid scenes: `asteroid-large-1`, `asteroid-large-2`, `asteroid-medium-1..3`, `asteroid-small-1..4`
- Each uses `components/asteroid.gd`, defines `max_health`, `death` (explosion scene), and `successors` (smaller asteroid variants) for splitting.

**`prefabs/coin/`**
- `coin-copper.tscn`, `coin-silver.tscn`, `coin-gold.tscn` — pickable coin items
- `coin-explosion.tscn` — coin scatter effect on death

**`prefabs/{weapon}/` (gausscannon, gravitygun, laser, minigun, rpg)**
- `{weapon}.tscn` — main weapon scene (extends `MountableWeapon` via `components/mountable-weapon.gd`, except gravity gun which uses `prefabs/gravitygun/gravitygun-script.gd`)
- `{weapon}-bullet.tscn` — projectile scene (extends `Bullet`)
- `{weapon}-bullet-explosion.tscn` — bullet impact effect
- `{weapon}-ammo.tscn` — pickable ammo item scene
- `{weapon}-item.tscn` — pickable weapon item scene
- `gravitygun-script.gd` — `GravityGun extends MountableWeapon`, overrides `fire()` for area effect

**`prefabs/ship-bfg-23/`**
- `ship-bfg-23.tscn` — player ship (uses `components/player-ship.gd`), three mount points, three propellers, picker area, three inventory nodes
- `ship-bfg-23-inventory.tscn` — inventory UI canvas layer, registers slots with ship inventories and links weapon slots to mount points
- `ship-bfg-23-inventory.gd` — script for above (not using `class_name`)
- `ship-bfg-23-explosion.tscn` — death explosion effect
- `Ship-bfg-23-propeller-main.tres`, `ship-bfg-23-propeller-left.tres`, `Ship-bfg-23-propeller-right.tres` — `PropellerMovementProfile` resources

**`prefabs/ui/`**
- `hud.tscn` / `hud.gd` (`HudDebugPanel`) — `CanvasLayer` showing health bar, coin count, and three weapon debug panels
- `status-bar.tscn` / `status-bar.gd` — `CanvasLayer` showing health % and coin count (simpler alternative HUD)
- `weapon-debug-panel.tscn` / `weapon-debug-panel.gd` (`WeaponDebugPanel`) — per-weapon stats display
- `controls-hint.tscn` — static UI showing keyboard bindings
- `inventory/inventory-slot.tscn` / `inventory/inventory-slot.gd` — base inventory slot UI component
- `inventory/slot-weapon.tscn`, `slot-engine.tscn`, `slot-item.tscn`, `slot-drop.tscn` — typed slot variants

**`sounds/`**
- Audio assets referenced directly from prefabs via `AudioStreamPlayer2D`.

**`images/`**
- Sprite textures referenced directly from prefabs via `Sprite2D`.

## Key File Locations

**Entry Point:**
- `world.tscn` — main scene, loaded by Godot at startup
- `world.gd` — main scene script, manages spawning and input

**Core Class Hierarchy:**
- `components/body.gd` — root game object class
- `components/mountable-body.gd` — all attachable bodies
- `components/mountable-weapon.gd` — all weapons
- `components/ship.gd` — ship logic

**Mount System:**
- `components/mount-point.gd` — connector node

**Inventory System:**
- `components/inventory.gd` — slot registry
- `components/inventory-slot.gd` — individual slot
- `components/item-type.gd` — item definition resource

**Physics & Combat:**
- `components/damage.gd` — damage resource
- `components/bullet.gd` — projectile logic
- `components/explosion.gd` — area effect on spawn

**Player Ship:**
- `prefabs/ship-bfg-23/ship-bfg-23.tscn` — ship scene
- `prefabs/ship-bfg-23/ship-bfg-23-inventory.tscn` — inventory UI

**HUD:**
- `prefabs/ui/hud.tscn` — main debug HUD
- `prefabs/ui/status-bar.tscn` — minimal status display

## Scene Hierarchy (world.tscn)

```
Node2D (world.gd)
├── CPUParticles2D              # Starfield background
├── ColorRect                   # Space background fill (z=-500)
├── Camera2D                    # Static overview camera
├── ShipCamera (BodyCamera)     # Ship-following camera (body_camera.gd)
├── CanvasModulate              # Global lighting dimmer
├── PointLight2D                # Sun/ambient light
├── Hud (HudDebugPanel)         # CanvasLayer — health/coins/weapon debug
├── Controls-hint               # CanvasLayer — keyboard help
├── ShipBFG23 (PlayerShip)      # Player ship RigidBody2D
│   ├── Sprite2D
│   ├── PropellerMain           # PropellerMovement node
│   ├── PropellerLeft
│   ├── PropellerRight
│   ├── PropellerMainEffect     # CPUParticles2D
│   ├── PropellerLeftEffect
│   ├── PropellerRightEffect
│   ├── MountPointDefault       # MountPoint (tag="")
│   ├── MountPointLeft          # MountPoint (tag="left")
│   ├── MountPointRight         # MountPoint (tag="right")
│   ├── CollisionPolygon2D
│   ├── PointLight2D
│   ├── LightOccluder2D
│   ├── Picker (Area2D)         # Item pickup trigger
│   ├── InventoryStorage        # Inventory node
│   ├── InventoryAmmo           # Inventory node
│   ├── InventoryDrop           # Inventory node
│   └── Ship-bfg-23-inventory   # CanvasLayer (inventory UI, hidden by default)
└── Coins (status-bar)          # CanvasLayer — health% and coin count
```

Asteroids are spawned dynamically at runtime by `world.gd.add_asteroid()` and added directly to the root `Node2D`.

Weapon scenes are spawned and reparented into `MountPoint` nodes on the ship at runtime via `mount_weapon()`.

Bullets, explosions, and item drops are spawned via `get_tree().current_scene.call_deferred("add_child", ...)`, making the root `Node2D` also the container for all runtime-spawned entities.

## Script Organization

**`class_name` defined (importable by Godot's type system):**
All files in `components/` define a `class_name` except none — every component script declares a class name, making them available globally without explicit imports.

**No `class_name` (anonymous scripts, attached to specific scenes only):**
- `world.gd`
- `prefabs/ship-bfg-23/ship-bfg-23-inventory.gd`
- `prefabs/ui/status-bar.gd` (extends CanvasLayer directly)

**Weapon-specific scripts outside `components/`:**
- `prefabs/gravitygun/gravitygun-script.gd` — only weapon script not in `components/`, because it extends `MountableWeapon` with specialized behavior

## Where to Add New Code

**New weapon type:**
- Add scenes to: `prefabs/{weapon-name}/` (weapon, bullet, ammo, item, explosion)
- Add item resource: `items/{weapon-name}.tres` and `items/{weapon-name}-ammo.tres`
- If default `MountableWeapon` behavior is sufficient: attach `components/mountable-weapon.gd` directly
- If custom fire logic needed: add script to `prefabs/{weapon-name}/{weapon-name}-script.gd` extending `MountableWeapon`
- Mount in world: call `mount_weapon($ShipBFG23, your_model, "")` in `world.gd._ready` or via keyboard shortcut

**New enemy type:**
- Add scene to `prefabs/{enemy-name}/`
- Attach `components/enemy-ship.gd` (or create a new script extending `EnemyShip`)
- Spawn from `world.gd` similar to `add_asteroid()`

**New item/pickup type:**
- Add to `ItemType.ItemTypes` enum in `components/item-type.gd`
- Create `.tres` file in `items/`
- Create scene in `prefabs/{item-name}/`
- Handle pickup in `Ship.picker_body_entered` match statement in `components/ship.gd`

**New component/utility:**
- If it's a reusable class: add `.gd` file to `components/` with a `class_name`
- If it's scene-specific: place alongside the scene in `prefabs/{name}/`

**New UI panel:**
- Add scene and script to `prefabs/ui/`
- Instantiate as a child of the root `Node2D` in `world.tscn`
- Connect to `$ShipBFG23` via exported `ship` or `body` variable

## Naming Conventions

**Files:**
- Kebab-case: `mountable-weapon.gd`, `ship-bfg-23.tscn`, `minigun-bullet.tscn`
- Exception: `body_camera.gd` uses underscore (only inconsistency)
- Prefab variants follow `{object}-{variant}.tscn` pattern

**Scripts:**
- `class_name` uses PascalCase: `MountableWeapon`, `PropellerMovement`, `HudDebugPanel`
- Variables and functions use snake_case throughout
- Exported properties use snake_case with descriptive names
