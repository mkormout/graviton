# Codebase Concerns

**Analysis Date:** 2026-04-07

---

## Tech Debt

### [High] String-based action dispatch instead of typed signals
- **Issue:** `do(sender, action: String, where: String, meta = null)` is used as a universal message bus across `MountableBody`, `MountPoint`, and `MountableWeapon`. Actions like `"fire"`, `"reload"`, `"godmode"`, `"recoil"`, `"use_ammo"`, `"use_rate"` are plain strings with no compile-time safety.
- **Files:** `components/mountable-body.gd:31`, `components/mount-point.gd:64`, `components/mountable-weapon.gd:77`
- **Impact:** Typos in action names fail silently. Adding a new action requires searching all call sites manually. The `meta` parameter is untyped (`= null`), making it invisible what each action expects.
- **Fix approach:** Replace string dispatch with typed signals or explicit virtual methods per action.

### [High] Reload signal re-connected on every reload call
- **Issue:** `reload_timer.connect("timeout", reloaded)` is called inside `reload()` without checking if already connected. Each reload call stacks another connection, so `reloaded()` fires multiple times per reload cycle after a few reloads.
- **Files:** `components/mountable-weapon.gd:69`
- **Impact:** Ammo refills multiple times per reload; can produce negative ammo counts or silent duplication.
- **Fix approach:** Connect once in `_ready()`, or use `connect(..., CONNECT_ONE_SHOT)` inside `reload()`.

### [Medium] `get_mounts()` runs `find_children` on every physics frame
- **Issue:** `MountableBody._physics_process()` calls `get_mounts()` each frame, which internally calls `find_children("*", "MountPoint")` — a full subtree scan every tick.
- **Files:** `components/mountable-body.gd:8-18`, `components/mountable-body.gd:45-46`
- **Impact:** Unnecessary CPU cost proportional to scene tree depth × mounted bodies × frame rate.
- **Fix approach:** Cache the mounts array and invalidate only when `mount_weapon` or `unmount_weapon` is called (already partially done via `mounts = get_mounts()` post-mount, but bypassed in `_physics_process` by calling `get_mounts()` directly inside property accessor for `body_opposite`).

### [Medium] `ItemType` uses runtime string-based path construction to load scenes
- **Issue:** `init()` constructs scene paths as `"res://prefabs/%s/%s.tscn"` from the `name` field. No validation, no error if the file does not exist; the engine will throw a runtime error.
- **Files:** `components/item-type.gd:28-30`
- **Impact:** A typo in the `name` export field of any `.tres` resource causes a crash with no graceful fallback.
- **Fix approach:** Use `@export var model: PackedScene` directly on `ItemType` to leverage Godot's asset reference system instead of string paths.

### [Medium] `ship.gd` `body_entered` creates a `RayCast2D` node that is never added to the scene tree
- **Issue:** `body_entered()` creates a `RayCast2D`, sets its target, then calls `get_collision_point()` on it — but the node is never added to the scene tree. `get_collision_point()` on an inactive raycast always returns `Vector2.ZERO`. The damage value is hardcoded at `1000 kinetic`.
- **Files:** `components/ship.gd:37-45`
- **Impact:** Collision damage logic is broken and non-functional. The raycast serves no purpose.
- **Fix approach:** Remove the raycast entirely or add the node to the scene and call `force_raycast_update()`. Parameterise the collision damage value via `@export`.

---

## Hardcoded Magic Numbers

### [Medium] World and physics constants scattered across files without names
- **Issue:** Spawn ranges (`MIN_RANGE = 4000`, `MAX_RANGE = 10000`), velocities (`MAX_LINEAR_VELOCITY = 1000`), asteroid ratio multipliers (`count * 0.5`, `count * 0.4`, `count * 0.1`), recoil place divisor (`/ 100`), and audio max distance (`30000`) are inline literals with no centralised configuration.
- **Files:** `world.gd:124-156`, `components/mountable-body.gd:37`, `components/random-audio-player.gd:12`
- **Fix approach:** Promote to named `const` values or `@export` parameters; or collect world-tuning constants into a `WorldSettings` autoload resource.

### [Low] Camera zoom values hardcoded in `BodyCamera`
- **Issue:** Default zoom `0.2`, max zoom diff `0.1`, and max speed `4000` are plain literals in `_process`.
- **Files:** `components/body_camera.gd:20-22`
- **Fix approach:** Expose as `@export` variables so scene instances can tune them without code changes.

---

## Debug Artifacts

### [Medium] Active `print` statement in production path
- **Issue:** `print("_get_drag_data: ", data)` fires on every drag interaction in the inventory UI.
- **Files:** `components/inventory-slot.gd:71`
- **Impact:** Noise in the output log; mild performance cost at scale.
- **Fix approach:** Remove or wrap in `if OS.is_debug_build()`.

### [Low] Commented-out `print` debug lines
- **Files:** `components/explosion.gd:89`, `components/body.gd:26`
- **Fix approach:** Remove entirely.

---

## Incomplete Implementations

### [High] `EnemyShip` and `PlayerShip` are empty stubs
- **Issue:** Both classes contain only a class declaration with no behaviour.
- **Files:** `components/enemy-ship.gd`, `components/player-ship.gd`
- **Impact:** Enemy AI does not exist. Player-specific input/abilities are absent. All input is handled in `world.gd` directly.

### [Medium] `_process(delta)` stubs with only `pass`
- **Issue:** Several files have generated `_process` stubs that were never implemented or cleaned up.
- **Files:** `prefabs/ship-bfg-23/ship-bfg-23-inventory.gd:40-41`, `prefabs/ui/hud.gd:20`, `components/mount-point.gd:19-20`, `components/propeller-movement.gd:25`

### [Medium] `world.gd` acts as a developer test harness, not a real game world
- **Issue:** All game setup (weapon mounting, asteroid spawning, keyboard shortcuts for switching weapons, godmode toggle) lives in `world.gd`. Keys Q/W/E, 1–6, A/S/D, G, H, J, R, I, C are bound directly in `_input` with no input map abstraction.
- **Files:** `world.gd:59-122`
- **Impact:** No separation between test scaffolding and actual game logic. Re-keying or building a proper UI requires rewriting this file.
- **Fix approach:** Move input handling into `PlayerShip`. Register actions in Godot's InputMap. Extract world initialisation into a level/scene manager.

---

## Fragile Areas

### [High] `get_tree().current_scene` used as a universal parent for spawned nodes
- **Issue:** Bullets, explosions, debris, item drops, death scenes, and reparented weapons all use `get_tree().current_scene` as the spawn target. If the scene hierarchy changes (e.g., adding a sub-viewport or changing the root node), all spawning breaks silently.
- **Files:** `components/mountable-weapon.gd:109`, `components/item-dropper.gd:18`, `components/mount-point.gd:43`, `components/body.gd:43`, `components/body.gd:65`, `components/explosion.gd:72`, `components/item.gd:12`
- **Fix approach:** Use a dedicated autoload `World` singleton with an `add_to_world(node)` method, or pass a spawn root reference explicitly.

### [Medium] `MountPoint.unplug` accesses `body_opposite` after setting `connection = null`
- **Issue:** `unplug` calls `slot.dec(body_opposite.item_type)` inside the lambda, but `connection` is set to `null` at line 56 before — or can be nulled mid-loop if a signal fires re-entrantly. The `body_opposite` getter returns `null` when `connection` is `null`, so `body_opposite.item_type` would crash.
- **Files:** `components/mount-point.gd:37-56`
- **Fix approach:** Cache `body_opposite` in a local variable before the null-assignment.

### [Medium] `Explosion.apply_shockwave` called after 0.1 s `await` but area may not yet be in tree
- **Issue:** `area` is added via `call_deferred("add_child", area)` in `initialize()`, then `explode()` awaits 0.1 s before calling `area.get_overlapping_bodies()`. This is a timing workaround; it is fragile under lag or if the deferred add is delayed further.
- **Files:** `components/explosion.gd:52-57`
- **Fix approach:** Connect to `area.body_entered` signal instead of polling after a fixed delay.

---

## Missing Features / Test Coverage Gaps

### [High] No automated tests of any kind
- No test files, no test framework configuration, no CI pipeline detected.
- **Risk:** Breakage in core systems (damage calculation, inventory slot management, weapon reload) is undetectable without manual play-testing.

### [Medium] No scene management or game loop
- There is one `world.tscn` with no main menu, pause menu, game-over state, or level transitions.

### [Low] `InventorySlot.has_type` compares by name string, not resource identity
- **Issue:** `return occupant and (type.name == occupant.name)` — two different `ItemType` resources with the same `name` field would be treated as identical.
- **Files:** `components/inventory-slot.gd:52`
- **Fix approach:** Compare resource identity directly: `return occupant == type` (works if the same resource instance is reused) or use a unique ID field.

---

*Concerns audit: 2026-04-07*
