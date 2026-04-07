# Coding Conventions

**Analysis Date:** 2026-04-07

## Naming Patterns

**Script files:**
- kebab-case for all `.gd` files: `player-ship.gd`, `item-dropper.gd`, `mountable-weapon.gd`
- Exception: two older files use snake_case — `zoom_level.gd`, `body_camera.gd` (inconsistency, not the pattern to follow)

**Class names:**
- PascalCase: `PlayerShip`, `MountableWeapon`, `ItemDropper`, `PropellerMovement`
- Always declared with `class_name` at the top of the file
- Class name matches the concept, not necessarily the file name exactly (e.g., `HudDebugPanel` in `hud.gd`)

**Functions:**
- snake_case: `pick_coin()`, `apply_shockwave()`, `register_slot()`, `get_body_opposite()`
- Godot lifecycle functions follow convention: `_ready()`, `_process()`, `_physics_process()`, `_input()`
- Private/internal handlers prefixed with `_on_`: `_on_slot_item_adding()`, `_on_slot_item_removing()`
- Slot/event handlers also prefixed with `_slot_`: `_slot_item_adding()`, `_slot_item_removing()`

**Variables:**
- snake_case: `max_health`, `reload_timer`, `magazine_current`, `body_opposite`
- Computed properties (via getter) use snake_case same as regular vars:
  ```gdscript
  var body_opposite: MountableBody:
      get: return get_body_opposite()
  ```
- `@onready` vars are snake_case: `weapon_front`, `mount_left`, `cooldown_timer`

**Constants:**
- SCREAMING_SNAKE_CASE: `MIN_RANGE`, `MAX_RANGE`, `MAX_LINEAR_VELOCITY`

**Signals:**
- Present-participle (gerund) naming — describes the event as it is happening:
  `plugging`, `unplugging`, `slot_item_adding`, `slot_item_removing`, `item_adding`, `item_removing`
- Signal parameters use descriptive names with types: `(sender: MountPoint, target: MountPoint)`

**Enum values:**
- SCREAMING_SNAKE_CASE inside PascalCase enum:
  ```gdscript
  enum ItemTypes { COIN, AMMO, WEAPON, HEALTH }
  enum ItemSlotType { STORAGE, WEAPON, UTIL, ENGINE, DROP, AMMO }
  ```

## Scene and Node Naming

**Scene files:**
- kebab-case with concept-variant pattern: `asteroid-large-1.tscn`, `minigun-bullet-explosion.tscn`
- Sub-components follow `{parent}-{role}.tscn`: `gausscannon-ammo.tscn`, `rpg-item.tscn`, `laser-bullet.tscn`

**Scene node names (within .tscn):**
- PascalCase for structural nodes: `ShipBFG23`, `WeaponFrontDebug`, `MarginContainer`
- kebab-case inside `$"..."` string references: `$"MarginContainer/TextureRect/Slot-weapon-front"`
- Slot node names use kebab-case with index: `Storage-slot-1`, `Ammo-slot-2`, `Drop-slot-1`

**Prefab directories:**
- kebab-case matching the weapon/entity name: `gravitygun/`, `ship-bfg-23/`, `laser/`

## Code Style

**Exports:**
- `@export` at top of class, before non-exported vars
- Export groups used to organize related properties:
  ```gdscript
  @export_group("Resources")
  @export var ammo: PackedScene
  @export_group("Firing")
  @export var rate: float
  ```

**Type annotations:**
- Return types annotated on most functions: `func has_ammo() -> bool`, `func drop() -> void`
- Parameter types generally annotated: `func damage(attack: Damage)`, `func plug(other: MountPoint)`
- Some older/simpler functions omit types: `func do(_sender: Node2D, action: String, _where: String, _meta = null)`
- Unused parameters prefixed with `_`: `_delta`, `_sender`, `_where`, `_at_position`

**Inheritance:**
- Classes explicitly state both `class_name` and `extends` on one line:
  `class_name Body extends RigidBody2D`
- Inheritance hierarchy: `Body` → `MountableBody` → `Ship` → `PlayerShip` / `EnemyShip`

**Preloads:**
- `preload()` used for scenes known at load time, declared as `var` at script top
- `load()` used for dynamic/conditional resource loading (inside `ItemType.init()`)

**Lambdas/callables:**
- Used inline for array filtering and slot iteration:
  ```gdscript
  slots.filter(func(slot: InventorySlot): return slot.has_type(type) and slot.has_space() if type else slot.is_empty())
  ```

**Comments:**
- Sparse — used for section labels (`# PHYSICAL LAYERS DESCRIPTION:`), intent clarification, or temporarily commented-out debug prints
- Godot auto-generated comments retained in some places: `# Called when the node enters the scene tree for the first time.`
- Commented-out `print()` statements left in place as lightweight debug markers

## Resource and Asset Naming

**Image files (`images/`):**
- kebab-case: `minigun-bullet.png`, `inventory-slot-blue.png`, `laser-item.png`
- Exception: coins use underscore — `coin_copper.png`, `coin_gold.png` (inconsistency)

**Resource files (`items/`, `.tres`):**
- kebab-case: `minigun-ammo.tres`, `gravitygun.tres`, `coin-gold.tres`

**Sound files (`sounds/`):**
- Not inspected in detail; directory present

## Scene Organization Pattern

Each weapon prefab directory contains a consistent set of files:
```
prefabs/{weapon}/
├── {weapon}.tscn          # Main weapon scene
├── {weapon}-ammo.tscn     # Ammo pickup scene
├── {weapon}-bullet.tscn   # Projectile scene
├── {weapon}-bullet-explosion.tscn  # Bullet hit effect
└── {weapon}-item.tscn     # Droppable world item
```

Components live flat in `components/` — no sub-grouping by type. Each component file defines exactly one class.

---

*Convention analysis: 2026-04-07*
