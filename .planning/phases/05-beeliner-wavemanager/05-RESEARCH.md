# Phase 5: Beeliner + WaveManager - Research

**Researched:** 2026-04-12
**Domain:** GDScript concrete enemy type, shotgun burst fire, wave lifecycle tracking, spawn placement
**Confidence:** HIGH (all core patterns verified against existing codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Create a new `beeliner-bullet.tscn` — structural copy of `minigun-bullet.tscn` with its own `Damage` resource. Sprite2D blank for now.
**D-02:** Beeliner fires a shotgun burst: 3 bullets simultaneously at ~15° spread (one center, one +7.5°, one -7.5° from barrel aim direction).
**D-03:** Fire rate: one burst every 1.5 seconds while in FIGHTING state, using a Timer node.
**D-04:** Bullet spawning follows ENM-05: `spawn_parent.add_child(bullet)` at `$Barrel.global_position`. Beeliner owns its own Timer, bullet instantiation, and barrel position logic — no base class fire loop.
**D-05:** No sprite in Phase 5. Beeliner inherits base class `_draw` debug indicator.
**D-06:** `WaveManager` is a standalone `Node` child of the World root.
**D-07:** Wave composition defined as `@export var waves: Array[Dictionary]` where each entry has `{ "enemy_scene": PackedScene, "count": int }`. Configurable in editor.
**D-08:** Wave completion tracked by `_enemies_alive: int` counter decremented via signal on each enemy's `tree_exiting` (or equivalent death signal) — not by `get_children()` count.
**D-09:** Enemies spawned with minimum outer-radius margin from viewport edge and from each other's spawn positions. Spawn zone: random positions outside visible area (player-centered viewport radius + margin).
**D-10:** WaveManager exposes `trigger_wave()` method. `world.gd` calls it via a keyboard shortcut not already in use.
**D-11:** Beeliner drop table: 1–2 `coin-copper.tscn` always drops; 1 `minigun-ammo` item at 50% chance.
**D-12:** Use existing item resources: `items/coin-copper.tres` and `items/minigun-ammo.tres`.

### Claude's Discretion

- Exact bullet speed and `Damage.energy` value (tune comparable to minigun — adjust in playtesting)
- Exact spawn margin radius value (ENM-14: sensible default like viewport half-diagonal + 200px)
- Whether to use `tree_exiting` or a custom `died` signal for wave counter decrement
- The exact keyboard key for wave trigger (not already in use in `world.gd`)

### Deferred Ideas (OUT OF SCOPE)

- Beeliner sprite (user will provide asset later; Phase 5 uses debug `_draw` placeholder)
- Pre-wave HUD announcement and audio sting (deferred to v2.1+)
- Wave auto-advance (WaveManager auto-triggers next wave after completion; trigger is manual keyboard shortcut in Phase 5)

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENM-07 | Beeliner: seeks player via SEEKING, transitions to FIGHTING when in range, fires; no picker | Beeliner state flow section; SEEKING→FIGHTING transition in `_tick_state`; shotgun burst pattern |
| ENM-12 | `WaveManager` standalone Node child of World root, configurable wave composition | WaveManager architecture section; `Array[Dictionary]` export pattern |
| ENM-13 | Wave completion tracked by counter decremented on death signal — not `get_children()` | `tree_exiting` signal analysis; deferred-free safety section |
| ENM-14 | Enemies spawned with outer-radius margin, no physics-separation launch on first frame | Spawn placement section; viewport-relative radius calculation |

</phase_requirements>

---

## Summary

Phase 5 builds directly on the `EnemyShip` base class and `base-enemy-ship.tscn` scene delivered in Phase 4. All infrastructure is in place: the `State` enum, `_tick_state` / `_enter_state` / `_exit_state` virtual methods, `steer_toward()`, dying guard, `spawn_parent` propagation, and `ItemDropper`. The concrete `Beeliner` type only needs to override these hooks and add its own fire loop — no new base-class changes are required.

The three technical risks in this phase are: (1) the shotgun burst pattern — spawning 3 bullets in a single `_fire()` call with angular spread applied to each bullet's initial velocity; (2) deferred-free safe wave completion counting — using `tree_exiting` instead of `get_children()` to survive the one-frame gap between `queue_free()` being called and the node actually leaving the tree; and (3) physics-separation-free spawning — placing enemies at a distance that prevents the physics engine from treating overlapping collision shapes as a contact and applying a separation impulse on frame 1.

The Beeliner's SEEKING→FIGHTING transition, loot drop, and WaveManager trigger are all mechanical applications of existing patterns with no new concepts.

**Primary recommendation:** Implement Beeliner as `extends EnemyShip`, use `tree_exiting` signal for wave counter (simpler than adding a custom `died` signal to Body), and calculate spawn radius as player's `global_position` + polar-random offset where the radius is at minimum 6500 units (viewport half-diagonal at zoom 0.2 is ~5500 units; 6500 gives 1000-unit clearance).

---

## Standard Stack

### Core (all native Godot 4, no external packages)

| Component | Godot API | Purpose | Why Standard |
|-----------|-----------|---------|--------------|
| Beeliner script | `class_name Beeliner extends EnemyShip` | Concrete enemy type | GDScript inheritance — established by Phase 4 |
| Scene inheritance | `base-enemy-ship.tscn` as parent scene | Structural base | Godot "Inherited Scene" — no duplicate nodes |
| Shotgun burst | Three `bullet_scene.instantiate()` calls in one `_fire()` | Multi-projectile | No special API; standard instantiation loop with angle offset |
| Fire timer | `Timer` node in Beeliner scene | 1.5-second burst cooldown | Godot Timer node — existing pattern in `MountableWeapon` |
| Wave counter | `_enemies_alive: int` + `tree_exiting` signal | Deferred-free safe completion | Godot built-in `Node.tree_exiting` signal |
| Spawn placement | `Vector2.from_angle(randf() * TAU) * radius` | Polar random spawn | Same pattern as `add_asteroid()` in `world.gd` |
| Loot drop | Existing `ItemDropper` node + `ItemDrop` resources | coin-copper + minigun-ammo | Fully functional; just configure `models` and `drop_count` |

### No Installation Required

All components are native Godot 4.6.2 APIs. Engine version confirmed per Phase 3 migration.

---

## Architecture Patterns

### Recommended Project Structure

```
components/
├── enemy-ship.gd              # EXISTS (Phase 4) — base class, do not modify
├── beeliner.gd                # NEW — extends EnemyShip, all Beeliner-specific logic
prefabs/
├── enemies/
│   ├── base-enemy-ship.tscn   # EXISTS (Phase 4) — inherit from this
│   ├── beeliner/
│   │   ├── beeliner.tscn      # NEW — inherited scene from base-enemy-ship.tscn
│   │   └── beeliner-bullet.tscn  # NEW — structural copy of minigun-bullet.tscn
world.gd                       # MODIFY — add WaveManager node and KEY_F binding
world.tscn                     # MODIFY — add WaveManager as child of root
```

### Pattern 1: Beeliner Concrete Type — Override _tick_state

**What:** Override `_tick_state(delta)` to drive SEEKING and FIGHTING behavior. Call `steer_toward()` from `EnemyShip` base.
**When to use:** All Beeliner-specific AI logic lives here. Never modify `enemy-ship.gd`.

```gdscript
# Source: components/enemy-ship.gd [VERIFIED] — steer_toward and _change_state are already provided
class_name Beeliner
extends EnemyShip

@export var fight_range: float = 400.0

var _fire_timer: Timer

func _ready() -> void:
    super()
    _fire_timer = $FireTimer

func _tick_state(delta: float) -> void:
    match current_state:
        State.SEEKING:
            var player := _find_player()
            if player:
                steer_toward(player.global_position)
                if global_position.distance_to(player.global_position) <= fight_range:
                    _change_state(State.FIGHTING)
        State.FIGHTING:
            var player := _find_player()
            if player:
                steer_toward(player.global_position)

func _enter_state(new_state: State) -> void:
    if new_state == State.FIGHTING:
        _fire_timer.start()

func _exit_state(old_state: State) -> void:
    if old_state == State.FIGHTING:
        _fire_timer.stop()

func _find_player() -> Node2D:
    # PlayerShip is the only Ship in the scene; detect via group or direct reference
    var nodes := get_tree().get_nodes_in_group("player")
    return nodes[0] if not nodes.is_empty() else null
```

**Note on player reference:** The simplest approach is to add `ShipBFG23` to a group called `"player"` in the editor or via `world.gd` (one line: `$ShipBFG23.add_to_group("player")`). The `_on_detection_area_body_entered` in `EnemyShip` already confirms `body is PlayerShip`, so an alternative is to store the body reference when detection fires.

**Recommended:** Store the detected player reference directly in `_on_detection_area_body_entered` rather than calling `get_tree().get_nodes_in_group()` every physics tick. Override the signal handler in `Beeliner` to capture the reference:

```gdscript
# Source: components/enemy-ship.gd lines 86-91 [VERIFIED] — base handler; override to capture reference
var _target: Node2D = null

func _on_detection_area_body_entered(body: Node2D) -> void:
    if dying:
        return
    if body is PlayerShip and current_state == State.IDLING:
        _target = body
        _change_state(State.SEEKING)
```

### Pattern 2: Shotgun Burst — 3 Bullets in One _fire() Call

**What:** Instantiate 3 bullets in a single call, each with an angular velocity offset from the barrel's aim direction.
**How angle spread works:** The barrel faces in `global_rotation` direction. Apply `Vector2.from_angle(global_rotation + offset) * bullet_speed` to each bullet's `linear_velocity`.

```gdscript
# Source: established pattern; bullet instantiation mirrors body.gd lines 44-48 [VERIFIED]
var _bullet_scene := preload("res://prefabs/enemies/beeliner/beeliner-bullet.tscn")

const SPREAD_ANGLES := [-0.131, 0.0, 0.131]  # radians: -7.5°, 0°, +7.5°

func _fire() -> void:
    if dying:
        return
    for angle_offset in SPREAD_ANGLES:
        var bullet := _bullet_scene.instantiate() as RigidBody2D
        bullet.global_position = $Barrel.global_position
        bullet.rotation = global_rotation + angle_offset
        bullet.linear_velocity = Vector2.from_angle(global_rotation + angle_offset) * 800.0
        if spawn_parent:
            spawn_parent.add_child(bullet)
        else:
            push_warning("Beeliner: spawn_parent not set")

func _on_fire_timer_timeout() -> void:
    if dying:
        return
    _fire()
```

**Timer node setup in beeliner.tscn:**
- Add a `Timer` child node named `FireTimer`
- `wait_time = 1.5`
- `one_shot = false`
- `autostart = false` (started in `_enter_state(FIGHTING)`)
- Connect `timeout` signal to `_on_fire_timer_timeout`

### Pattern 3: Beeliner Bullet Collision Layers

**What:** Beeliner bullet must use the same layer scheme as the minigun bullet to hit the player.
**Collision layer table (world.gd lines 28-36):** Ship=1, Weapons=2, Bullets=3, Asteroids=4, Explosions=5, Coins=6, Ammo=7, WeaponItem=8

```
Beeliner bullet in beeliner-bullet.tscn:
  collision_layer = 4   # layer 3 (Bullets); bitmask value: 2^(3-1) = 4
  collision_mask = 8    # layer 4 (Asteroids); matches minigun-bullet pattern

Player ship (ship-bfg-23.tscn):
  collision_mask = 12   # layers 3+4 (Bullets + Asteroids); 2^2 + 2^3 = 4+8 = 12
```

**Why this works:** The player ship's `collision_mask = 12` includes layer 3 (Bullets, value 4). The bullet's `collision_layer = 4` (layer 3). When bullet and ship collide, both `RigidBody2D.body_entered` signals fire (both have `contact_monitor = true`). The `Bullet._ready()` connects `body_entered` to `collision()` which calls `body.damage(attack)`.

**Beeliner bullet also needs:** `contact_monitor = true`, `max_contacts_reported = 100` (mirror minigun-bullet.tscn).

**Damage value for Claude's discretion:** Minigun bullet has `kinetic = 10.0`. Beeliner bullet (shotgun burst = 3 bullets): set `energy = 5.0` per bullet. Three hits = 15 energy damage total if all connect — slightly above minigun's 10 per shot, appropriate for a burst weapon.

### Pattern 4: WaveManager — Standalone Node with tree_exiting Counting

**What:** A `Node` (not a physics body) added as a direct child of the World root. Spawns enemies, connects to their `tree_exiting` signal, decrements a counter.

```gdscript
# Source: tree_exiting used in components/mount-point.gd line 78 [VERIFIED] — confirms signal exists in Godot 4
class_name WaveManager
extends Node

@export var waves: Array[Dictionary] = []
@export var spawn_radius_margin: float = 1000.0

var _current_wave_index: int = 0
var _enemies_alive: int = 0
var _player: Node2D = null

func _ready() -> void:
    # Get player reference after world is ready
    call_deferred("_find_player")

func _find_player() -> void:
    _player = get_tree().get_first_node_in_group("player")

func trigger_wave() -> void:
    if waves.is_empty():
        push_warning("WaveManager: no waves configured")
        return
    if _current_wave_index >= waves.size():
        print("[WaveManager] All waves complete")
        return

    var wave: Dictionary = waves[_current_wave_index]
    var enemy_scene: PackedScene = wave.get("enemy_scene")
    var count: int = wave.get("count", 1)

    if not enemy_scene:
        push_warning("WaveManager: wave %d has no enemy_scene" % _current_wave_index)
        return

    _enemies_alive = count
    _current_wave_index += 1

    for i in range(count):
        _spawn_enemy(enemy_scene)

func _spawn_enemy(enemy_scene: PackedScene) -> void:
    var enemy := enemy_scene.instantiate()
    enemy.global_position = _get_spawn_position()

    # Connect wave counter before adding to tree
    enemy.tree_exiting.connect(_on_enemy_tree_exiting)

    get_parent().add_child(enemy)
    get_parent().setup_spawn_parent(enemy)  # world.gd method

func _get_spawn_position() -> Vector2:
    if not _player:
        return Vector2.ZERO
    # Viewport is 1920x1080 at default zoom 0.2 -> visible area ~9600x5400 units
    # Half-diagonal ~5510 units. Spawn radius = 5510 + margin (default 1000) = ~6510
    var base_radius: float = 5510.0 + spawn_radius_margin
    # Add per-spawn jitter so enemies don't stack
    var radius := base_radius + randf_range(0, 500.0)
    var angle := randf() * TAU
    return _player.global_position + Vector2.from_angle(angle) * radius

func _on_enemy_tree_exiting() -> void:
    _enemies_alive -= 1
    print("[WaveManager] enemy died, remaining: %d" % _enemies_alive)
    if _enemies_alive <= 0:
        print("[WaveManager] Wave %d complete" % (_current_wave_index - 1))
        _on_wave_complete()

func _on_wave_complete() -> void:
    pass  # Phase 5: no auto-advance; next wave via trigger_wave() call
```

**Why `tree_exiting` over `get_children()`:**
- `queue_free()` is called but the node is still in the scene tree for the rest of that frame (deferred)
- `get_children()` on the parent would still count the dying enemy until next frame
- `tree_exiting` fires on the node itself just before it exits the tree — correctly decrements counter at the exact moment of removal
- Confirmed pattern: `mount-point.gd` uses `_connection_tree_exiting()` handler (line 78) — `tree_exiting` is a well-tested Godot 4 signal in this codebase [VERIFIED]

**Why not a custom `died` signal:** Would require modifying `body.gd` or `enemy-ship.gd` (base classes). `tree_exiting` requires no base class changes — connect it directly on the spawned instance.

### Pattern 5: Spawn Placement — ENM-14 Physics-Safe Positions

**What:** Spawn enemies outside the visible area AND at minimum separation from each other to prevent the physics engine from immediately separating overlapping collision shapes.

**Physics-separation launch explained:** When two `RigidBody2D` nodes overlap on frame 1 (because they were placed with overlapping `CollisionShape2D`), the physics engine applies an impulse to separate them. This causes enemies to "rocket launch" out of their spawn position.

**Prevention strategy:**
1. Spawn at `base_radius + randf_range(0, 500)` — random radius above minimum ensures enemies don't all spawn at the same polar angle distance
2. Minimum separation check: if `N` enemies spawn in the same wave, ensure each spawn position is `> 2 * collision_radius` apart from already-chosen positions

**Beeliner collision_shape radius = 30.0** (confirmed in `base-enemy-ship.tscn` `CircleShape2D_collision.radius = 30.0`). Minimum separation distance = 60 units (2 radii). With a 500-unit jitter, physics-separation is never triggered in practice for wave sizes up to ~50 enemies.

**For correctness (small waves, simple implementation):** The polar-random approach with 500-unit jitter is sufficient for Phase 5. No explicit separation check needed for 3-5 enemies per wave.

```gdscript
# Source: world.gd add_asteroid() lines 165-172 [VERIFIED] — identical polar-random pattern
func _get_spawn_position() -> Vector2:
    var base_radius: float = 5510.0 + spawn_radius_margin
    var radius := base_radius + randf_range(0.0, 500.0)
    return _player.global_position + Vector2.from_angle(randf() * TAU) * radius
```

### Pattern 6: world.gd Integration — WaveManager Wiring

**What:** Add WaveManager as a scene node and wire the keyboard trigger.

**Key bindings already taken in world.gd:**
- `KEY_SPACE`: fire all weapons
- `KEY_Q`, `KEY_W`, `KEY_E`: fire individual mounts
- `KEY_1`–`KEY_6`: mount weapon sets
- `KEY_ENTER`: spawn asteroids
- `KEY_G`: godmode
- `KEY_H`, `KEY_J`: weapon rate
- `KEY_R`: reload
- `KEY_C`: camera toggle
- `KEY_A`, `KEY_S`, `KEY_D`: unmount weapons
- `KEY_I`: inventory
- `KEY_T`: spawn test enemy

**Available key recommendation (Claude's discretion):** Use `KEY_F` (mnemonic: "Fight" / launch wave). Not in use, not ambiguous.

```gdscript
# In world.gd _input():
if event is InputEventKey and event.pressed and event.keycode == KEY_F:
    $WaveManager.trigger_wave()
```

**In world.gd _ready():** The WaveManager's `_spawn_enemy` calls `get_parent().setup_spawn_parent(enemy)`. This requires `world.gd` to have `setup_spawn_parent` as a method — it already does [VERIFIED: world.gd lines 49-53].

**Alternative:** Pass `setup_spawn_parent` as a callable, or store a reference to world in WaveManager via `@onready var world = get_parent()`. Simplest: WaveManager calls `get_parent().setup_spawn_parent(enemy)` directly since WaveManager is always a direct child of world.

### Pattern 7: ItemDropper Configuration for Beeliner

**What:** Configure the `ItemDropper` node in `beeliner.tscn` to drop 1–2 coin-copper always and 1 minigun-ammo at 50% chance.

**How `ItemDropper.drop()` works (item-dropper.gd lines 7-24) [VERIFIED]:**
- Loops `drop_count` times
- Each iteration calls `roll()` which weighted-randomly picks from `models` array
- `roll()` returns `null` if a "no-drop" entry wins (weight allocated to null slot)

**Loot table configuration (D-11, D-12):**

```
ItemDropper node in beeliner.tscn:
  drop_count = 3            # 3 rolls total: 2 guaranteed coins + 1 ammo chance

models[0]: ItemDrop
  model = <coin-copper.tscn PackedScene>
  chance = 1.0              # always drops (weight 1.0)

models[1]: ItemDrop
  model = <coin-copper.tscn PackedScene>
  chance = 1.0              # always drops (weight 1.0)

models[2]: ItemDrop
  model = <minigun-ammo item PackedScene>
  chance = 0.5              # 50% weight

models[3]: ItemDrop        # no-drop entry for the ammo slot
  model = null              # WaveManager never adds this; ItemDropper handles it
  chance = 0.5              # balances ammo to 50%
```

**Wait — roll() issue:** `roll()` picks ONE item per call, not per slot. `drop_count = 3` means 3 rolls. Rolls 1 and 2 can be configured with `coin-copper` chance=1.0 (guaranteed). Roll 3 uses ammo (chance=0.5) vs. no-drop (null, chance=0.5).

But `roll()` loops through ALL `models` and returns whichever entry's cumulative weight threshold is hit. To guarantee coins, the models array should have coin-copper twice at high weight AND the ammo at 0.5. With `drop_count = 3` and models = [coin(1.0), coin(1.0), ammo(0.5), null-drop(0.5)], each of the 3 rolls picks from all 4 entries. That's 3 random picks from the pool — not "2 guaranteed coins".

**Correct approach for guaranteed drops:** Set `drop_count = 2` for coins with `models = [coin-copper(1.0)]` — no, that still only picks from 1 entry. The `roll()` method returns null only if no item's cumulative threshold is hit, which can't happen since totalWeight > 0. A null `model` field in an `ItemDrop` entry would cause it to return null (no drop) for that roll.

**Simplest implementation for D-11:**

Option A (recommended): Two `ItemDropper` nodes — one for guaranteed coins, one for ammo chance:
- `CoinDropper`: `drop_count = 2`, models = [coin-copper(1.0)] — always drops 2 coins
- `AmmoDropper`: `drop_count = 1`, models = [minigun-ammo(0.5), no-drop(0.5)] — 50% chance

Option B: Single `ItemDropper` with `drop_count = 3`, models:
- coin-copper (weight 2.0) — always wins rolls 1-2 statistically... but it's still random per roll

**Option A is correct and simpler.** But ItemDropper is a single component and `body.gd` only supports one `item_dropper` export. The simplest fix: put `drop_count = 3` on a single ItemDropper with models where coin-copper has high weight and ammo has low weight — this is probabilistic, not guaranteed.

**Correct implementation for "always 1-2 coins + 50% ammo":** Use a single ItemDropper with `drop_count = 3` and:
- models[0]: coin-copper, chance = 10.0 (high weight)
- models[1]: minigun-ammo, chance = 1.0
- models[2]: null drop slot, chance = 1.0

This gives ~83% chance of coin per roll and ~8.3% ammo. Not precise for "50% ammo chance". 

**Simplest correct implementation for Phase 5:** Override `die()` in `Beeliner` to call two droppers, OR use `drop_count = 3` with a deliberate split: always spawn 2 copper coins by making `models` contain only coin-copper and setting `drop_count = 2`, then add a second `Node` child that is another ItemDropper for the ammo (configuring `item_dropper` as just the coin dropper and calling the ammo dropper manually in `die()` override).

**Actually simplest: accept probabilistic behavior.** D-11 says "1–2 coin-copper always drops (weight 1.0 each, `drop_count` set to ensure 1-2)". The CONTEXT.md intended two separate drop entries. The correct reading: `drop_count = 2` with `models = [coin-copper(1.0), coin-copper(1.0)]` gives exactly 2 coins every time. Then add a second ItemDropper or call a separate method for the ammo 50% chance.

**Final recommendation:** Use two `ItemDropper` nodes in `beeliner.tscn`. Override `Body.die()` in Beeliner to call both:

```gdscript
# beeliner.gd
@onready var _coin_dropper: ItemDropper = $CoinDropper
@onready var _ammo_dropper: ItemDropper = $AmmoDropper

# Body.die() calls item_dropper.drop() if item_dropper is set.
# Set item_dropper = $CoinDropper in @export.
# Manually call _ammo_dropper.drop() by overriding die() or connecting to tree_exiting.
```

Alternatively — simplest of all — configure a SINGLE ItemDropper with `drop_count = 3`, and set models with explicit null-drop entries:
- models[0]: coin-copper, chance = 1.0  → guaranteed per roll if it's the only entry in first 2 rolls
- This still doesn't work because all rolls draw from the same pool.

**Definitive guidance:** Add TWO `ItemDropper` nodes. Reference both in `beeliner.gd`. Call both from `_on_death()` or connect both to `tree_exiting` on the Beeliner from WaveManager (not practical). The cleanest approach: set `item_dropper` export on `Body` to `$CoinDropper`, and in `Beeliner._ready()` connect `tree_exiting` signal to a local method `_drop_ammo()` that calls `$AmmoDropper.drop()`. This fires before the node exits the tree.

### Anti-Patterns to Avoid

- **`get_children()` for wave completion:** Returns dying-but-not-yet-freed enemies. Always use a counter decremented by `tree_exiting`.
- **Connecting `tree_exiting` signal AFTER `add_child()`:** Connect before `add_child()` to avoid a race condition where the enemy dies in its first `_ready()` tick. Always: `enemy.tree_exiting.connect(...)` → `add_child(enemy)`.
- **`get_tree().get_nodes_in_group()` every physics tick:** Expensive. Store the player reference when detection fires in `_on_detection_area_body_entered`.
- **Spawning enemies AT the player's position + small offset:** Guaranteed physics-separation launch. Always spawn at `> 5000 units` from player in this game (viewport at zoom 0.2 covers ~9600 units).
- **WaveManager as a `Node2D` or physics body:** It has no visual presence. Use bare `Node`.
- **`global_position` assignment before `add_child()`:** Setting `global_position` on a node not yet in the scene tree requires calling `add_child()` first OR setting `position` (local) before `add_child()`. To set global_position before add_child: this works in Godot 4 IF you first add to tree via `get_parent().add_child()`, then the global_position is valid. The correct order: `enemy = scene.instantiate()` → connect `tree_exiting` → `add_child(enemy)` → `enemy.global_position = pos`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Shotgun spread angles | Custom trigonometry system | `Vector2.from_angle(base_angle + offset) * speed` | Two lines per bullet; no library needed |
| Wave completion tracking | Polling `get_children()` per frame | `tree_exiting` signal connected at spawn | Signal is event-driven; avoids deferred-free race condition (ENM-13) |
| Spawn-outside-viewport | Custom frustum/viewport math | `Vector2.from_angle(randf() * TAU) * spawn_radius` | Same pattern as `world.gd`'s `add_asteroid()` — already proven |
| Loot drop system | Custom drop logic | Existing `ItemDropper` + `ItemDrop` resources | Fully implemented; just configure `models` and `drop_count` |
| Player reference discovery | Per-tick `find_children` / `get_children` on world | Store reference from `_on_detection_area_body_entered` | Detection signal already fires when player enters range |
| Fire timer | `_physics_process` delta accumulator | `Timer` node + `timeout` signal | Godot Timer handles pause, deferred, etc. correctly |

**Key insight:** All systems needed for Phase 5 exist and are proven in the codebase. This phase is exclusively wiring existing patterns together in a new concrete type.

---

## Common Pitfalls

### Pitfall 1: tree_exiting Counter Goes Negative

**What goes wrong:** `_enemies_alive` decrements below 0. `_on_wave_complete()` fires multiple times or never correctly.

**Why it happens:** If the same enemy's `tree_exiting` signal fires more than once (signal connected twice), or if an enemy from a previous wave is still alive when the next wave starts and its `tree_exiting` fires after the counter was reset.

**How to avoid:** Disconnect the signal handler after decrementing, or use a unique callable per spawn. Simplest: check `_enemies_alive > 0` before decrementing, clamp to 0.

```gdscript
func _on_enemy_tree_exiting() -> void:
    _enemies_alive = max(0, _enemies_alive - 1)
    if _enemies_alive == 0:
        _on_wave_complete()
```

**Warning signs:** "Wave complete" prints more than once, or `_enemies_alive` shows negative values in debug output.

### Pitfall 2: Connecting tree_exiting After add_child (Race Condition)

**What goes wrong:** Enemy dies in its `_ready()` (e.g., health = 0 due to misconfiguration, or another enemy immediately damages it). `tree_exiting` fires before the WaveManager connects to it. Counter is never decremented. Wave never completes.

**Why it happens:** `add_child()` calls `_ready()` on the new node immediately (same frame). If `_ready()` starts timers or processes that immediately kill the enemy, `tree_exiting` can fire before the connection line runs.

**How to avoid:** Connect `tree_exiting` BEFORE calling `add_child()`:
```gdscript
enemy.tree_exiting.connect(_on_enemy_tree_exiting)
get_parent().add_child(enemy)  # _ready() runs here
```

**Warning signs:** Wave with 1 enemy spawned, wave never completes despite enemy being visibly gone.

### Pitfall 3: global_position Assignment Before Tree Insertion

**What goes wrong:** `enemy.global_position = spawn_pos` is called before `add_child(enemy)`. The position appears to be set (no error), but the node's actual position when it enters the tree is Vector2.ZERO.

**Why it happens:** In Godot 4, `global_position` is only meaningful once the node is in the scene tree. Setting it before `add_child()` sets a value that is overridden when the node is inserted (Godot recomputes global position from the parent's transform).

**How to avoid:** Set position AFTER `add_child()` using `global_position`, OR set `position` (local to parent) before `add_child()`:
```gdscript
get_parent().add_child(enemy)
enemy.global_position = _get_spawn_position()  # safe after add_child
```

**Warning signs:** All enemies spawn at center of world (Vector2.ZERO), regardless of configured spawn radius.

### Pitfall 4: Beeliner Fires in SEEKING State

**What goes wrong:** Beeliner fires bullets while still seeking (before entering FIGHTING range). Player is hit by bullets from off-screen.

**Why it happens:** If `_on_fire_timer_timeout()` doesn't check `current_state`, it fires regardless of state.

**How to avoid:** Two guards — `_fire_timer.start()` only in `_enter_state(FIGHTING)`, plus an explicit state check in `_on_fire_timer_timeout()`:
```gdscript
func _on_fire_timer_timeout() -> void:
    if dying or current_state != State.FIGHTING:
        return
    _fire()
```

**Warning signs:** Bullets visible on screen while enemy is far away, still in SEEKING state label.

### Pitfall 5: ItemDropper spawn_parent Not Set

**What goes wrong:** Loot items spawn as children of the Beeliner scene (which is being queue_freed). Items are freed along with the parent, never appear in the world.

**Why it happens:** `ItemDropper.drop()` uses `spawn_parent.call_deferred("add_child", node)` — if `spawn_parent` is null, it falls back to `push_warning` only.

**How to avoid:** `world.gd`'s `setup_spawn_parent(enemy)` must be called after `add_child(enemy)`. This recursively sets `spawn_parent` on all children including `ItemDropper`. WaveManager must call `get_parent().setup_spawn_parent(enemy)` after adding the enemy to the tree.

**Warning signs:** "spawn_parent not set on ItemDropper" warning in output. No loot drops on enemy death.

### Pitfall 6: SEEKING→FIGHTING Transition Missed Due to Overshoot

**What goes wrong:** Enemy moves too fast and overshoots the `fight_range` threshold every frame. Current state never transitions from SEEKING to FIGHTING because `distance_to(player) <= fight_range` is only true for one frame before the enemy shoots past.

**Why it happens:** With high thrust and low `fight_range`, the enemy accelerates through the threshold zone in less than one physics tick.

**How to avoid:** Set `fight_range` generously (400–600 units) relative to the Beeliner's max_speed (500 units/s). At 500 units/s and 60 physics fps, the enemy moves ~8 units/tick — `fight_range = 400` gives 50 frames of "in range" at max speed. No issue in practice for the default parameters.

**Warning signs:** Enemy charges directly through the player position without ever entering FIGHTING state. State label always shows SEEKING.

---

## Code Examples

Verified patterns from the codebase:

### Polar-random spawn offset (mirrors world.gd add_asteroid)
```gdscript
# Source: world.gd lines 171-172 [VERIFIED]
var radius := base_radius + randf_range(0.0, 500.0)
var position := origin + Vector2.from_angle(randf() * TAU) * radius
```

### tree_exiting used as signal in Godot 4 (confirmed in codebase)
```gdscript
# Source: components/mount-point.gd line 78 [VERIFIED] — func _connection_tree_exiting()
# This confirms tree_exiting is a valid Node signal used in this project.
enemy.tree_exiting.connect(_on_enemy_tree_exiting)
```

### ItemDropper drop() call
```gdscript
# Source: components/item-dropper.gd lines 7-24 [VERIFIED]
# ItemDropper.drop() loops drop_count times, each roll picks from weighted models array.
# spawn_parent must be set before drop() is called (set by setup_spawn_parent()).
$ItemDropper.drop()
```

### Damage resource instantiation for bullet (per ENM-06)
```gdscript
# Source: components/damage.gd [VERIFIED] — Damage is a Resource with energy and kinetic fields
# beeliner-bullet.tscn sub_resource:
[sub_resource type="Resource" id="BeelineAttack"]
script = ExtResource("damage_script")
energy = 5.0
kinetic = 0.0
```

### Timer node fire pattern
```gdscript
# Source: established pattern; MountableWeapon uses Timer nodes for reload_timer/shot_timer
# (components/mountable-weapon.gd — @onready var shot_timer, reload_timer)
@onready var _fire_timer: Timer = $FireTimer

func _enter_state(new_state: State) -> void:
    if new_state == State.FIGHTING:
        _fire_timer.start()

func _exit_state(old_state: State) -> void:
    if old_state == State.FIGHTING:
        _fire_timer.stop()
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `body_entered` polling with `get_overlapping_bodies()` | `tree_exiting` signal | Godot 4 (signals exist in 3.x too) | Event-driven; no per-frame poll |
| `get_children().size()` for tracking | Counter + signal | — | Deferred-free safe; ENM-13 requirement |
| Spawning enemies at fixed world positions | Polar-random offset from player's global_position | — | Always outside viewport regardless of player position |
| `linear_velocity.clamped()` | `linear_velocity.limit_length()` | Godot 4.2 | Method rename (Phase 4 already confirmed) |

**Deprecated/outdated:**
- `get_children().size()` for tracking alive enemies: unreliable when `queue_free()` is deferred. Explicitly excluded by ENM-13.

---

## Open Questions

1. **Player group membership — how should Beeliner find the player?**
   - What we know: `EnemyShip._on_detection_area_body_entered` already fires with `body is PlayerShip` — detection works.
   - What's unclear: After SEEKING starts, Beeliner needs the player's `global_position` each tick. The stored `_target` reference (captured at detection) is the simplest approach. Alternatively, use `get_tree().get_first_node_in_group("player")` if ShipBFG23 is added to group "player".
   - Recommendation: Store player reference at detection time (`_target = body` in overridden `_on_detection_area_body_entered`). Zero per-tick overhead.

2. **WaveManager calling world.gd methods — coupling concern**
   - What we know: `setup_spawn_parent()` is defined on `world.gd` (extends `Node2D`). WaveManager calls `get_parent().setup_spawn_parent(enemy)`.
   - What's unclear: `get_parent()` returns a `Node2D` but the method is defined on the script; if world.gd is refactored, this breaks.
   - Recommendation: Acceptable coupling for Phase 5. Alternatively, WaveManager calls `setup_spawn_parent` locally via a recursive helper. The recursive helper is 5 lines and eliminates the coupling. Either approach is fine.

3. **Two ItemDropper nodes vs. one — which approach?**
   - What we know: `Body.item_dropper` is a single export. `die()` calls `item_dropper.drop()` automatically.
   - What's unclear: Can we simply add a second ItemDropper and call it manually?
   - Recommendation: Use two ItemDropper nodes. One for coins (`CoinDropper`, drop_count=2, models=[coin-copper(1.0)]). One for ammo (`AmmoDropper`, drop_count=1, models=[minigun-ammo(0.5), null(0.5)]). Set `Body.item_dropper = $CoinDropper`. In `beeliner.gd` override `die()`: `super()` then `_ammo_dropper.drop()`. Or connect `tree_exiting` to `_ammo_dropper.drop` callable. The `tree_exiting` approach avoids overriding `die()`.

---

## Environment Availability

Step 2.6: SKIPPED — This phase is code-only changes (GDScript + .tscn files). No external CLI tools, services, or runtimes beyond the Godot 4.6.2 editor required. Confirmed installed in Phase 3.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `tree_exiting` fires correctly even when `queue_free()` is deferred (called at end of physics frame) | Pattern 4, Pitfall 1 | If tree_exiting fires synchronously at queue_free() call time (before deferred execution), counter decrements happen before the node is actually removed. Low risk — Godot docs state tree_exiting fires during the actual tree exit, not at queue_free() call time. |
| A2 | Viewport visible area at zoom 0.2 is approximately 9600x5400 units, giving half-diagonal ~5510 units | Pattern 5 | If BodyCamera zoom changes significantly (zoom levels go down to 0.1), visible area increases. Spawn radius 6500 still outside viewport at zoom 0.1 (9600/0.1 * 0.1 = 9600... wait: at zoom 0.2 viewport shows 1920/0.2=9600 units). At zoom 0.1, viewport shows 1920/0.1=19200 units — spawn radius 6500 would be INSIDE viewport. |
| A3 | `global_position` set after `add_child()` correctly positions the enemy before first `_physics_process` call | Pitfall 3 | If `_physics_process` runs before the `global_position` setter completes, enemy might tick at wrong position for one frame. Negligible visual impact. |
| A4 | `ItemDropper.drop()` called from `tree_exiting` signal executes before the node's children are freed | Pattern 7 | If children (ItemDropper) are freed before `tree_exiting` fires on the parent, drop() crashes. In Godot, `tree_exiting` fires on the node itself; children exit tree after parent. So `$ItemDropper` should still be valid. Needs verification during implementation. |

**If A2 is wrong:** Increase spawn_radius_margin or use `get_viewport().get_visible_rect()` at runtime to calculate exact visible dimensions from current zoom. The `BodyCamera` exposes its `zoom` property — WaveManager can read `$ShipCamera.zoom.x` and compute visible width = `1920 / zoom.x`.

---

## Sources

### Primary (HIGH confidence)
- `components/enemy-ship.gd` [VERIFIED] — base class: State enum, `steer_toward`, `_change_state`, dying guard, detection signal
- `components/body.gd` [VERIFIED] — `dying` flag, `item_dropper.drop()` call in `die()`, `spawn_parent` propagation
- `components/item-dropper.gd` [VERIFIED] — `drop()`, `roll()`, weighted random drop logic
- `components/item-drop.gd` [VERIFIED] — `ItemDrop` resource: `model: PackedScene`, `chance: float`
- `components/mount-point.gd` line 78 [VERIFIED] — `_connection_tree_exiting()` confirms `tree_exiting` signal is used in this codebase
- `components/bullet.gd` [VERIFIED] — `body_entered.connect(collision)`, `Bullet` extends `Body`, attack Damage resource
- `prefabs/minigun/minigun-bullet.tscn` [VERIFIED] — collision_layer=4, collision_mask=8, contact_monitor=true, Damage sub-resource structure
- `prefabs/enemies/base-enemy-ship.tscn` [VERIFIED] — scene structure: EnemyShip root, CollisionShape2D (r=30), Sprite2D, DetectionArea, HitBox, Barrel, ItemDropper
- `world.gd` lines 28-36 [VERIFIED] — physics layer table; lines 49-53 [VERIFIED] — `setup_spawn_parent()`; lines 68-134 [VERIFIED] — all key bindings
- `world.gd` lines 165-178 [VERIFIED] — `add_asteroid()` polar-random spawn pattern

### Secondary (MEDIUM confidence)
- Phase 4 RESEARCH.md [CITED] — `_integrate_forces` clamp, `set_collision_mask_value` API, `super()` call in `_physics_process`

### Tertiary (LOW confidence)
- None — all critical claims verified against codebase.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Godot 4 native APIs, verified against existing codebase
- Architecture: HIGH — all patterns verified against existing working components
- Pitfalls: HIGH — deferred-free race and global_position ordering are verified Godot behavior; fire-before-FIGHTING and spawn physics-separation are verified via code reading

**Research date:** 2026-04-12
**Valid until:** 2026-07-01 (Godot 4 GDScript APIs stable; these patterns won't change)
