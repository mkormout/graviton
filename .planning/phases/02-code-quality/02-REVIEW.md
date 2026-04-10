---
phase: 02-code-quality
reviewed: 2026-04-07T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - components/mountable-body.gd
  - components/mountable-weapon.gd
  - components/mount-point.gd
  - components/inventory-slot.gd
  - world.gd
findings:
  critical: 2
  warning: 2
  info: 2
  total: 6
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-07
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

The phase 2 changes successfully introduced the `MountableBody.Action` enum and migrated all call sites. The `inventory-slot.gd` debug print removal is clean. However, the mount caching change in `mountable-body.gd` introduced a regression: weapons (which are themselves `MountableBody` instances) never have their own `mounts` array populated, so `get_mount("")` always returns null on a weapon, causing a null-call crash when `fire()` tries to dispatch recoil. Additionally, `world.gd` has a pre-existing float-to-range bug in `spawn_asteroids()` that will error in Godot 4. Two warnings cover the stale `mounts` cache after unmounting and the `mount_weapon()` flow that bypasses `setup_spawn_parent` for freshly-mounted weapons in `world.gd`.

---

## Critical Issues

### CR-01: Weapon `mounts` cache never populated — null crash on recoil dispatch

**File:** `components/mountable-weapon.gd:127-128`

**Issue:** `fire()` calls `get_mount("")` on `self` (the weapon) to dispatch the recoil impulse up the mount chain. `get_mount()` iterates `self.mounts`, which is an inherited `MountableBody` instance variable initialized to `[]`. The only place `mounts` is refreshed is inside `MountableBody.mount_weapon()` — which is called on the **parent ship**, not on the weapon. The weapon's own `mounts` array is never populated after the phase 2 caching change (previously `get_mount()` called `find_children()` live; now it reads the cached array). Result: `get_mount("")` returns null every time, and `null.do(...)` on line 128 is a runtime crash whenever any weapon fires.

**Fix:** Populate `mounts` lazily in `MountableBody._ready()` so every instance (ship and weapon alike) caches its own children on enter-tree:

```gdscript
# components/mountable-body.gd
func _ready() -> void:
    mounts = get_mounts()
```

Alternatively, call `get_mounts()` once inside `MountableWeapon._ready()` after `super._ready()` (if a `_ready` chain is preferred). Either approach ensures the weapon's own `""` MountPoint child is present in its `mounts` array before `fire()` is ever called.

---

### CR-02: `spawn_asteroids()` passes float to `range()` — runtime error in Godot 4

**File:** `world.gd:132-138`

**Issue:** `range()` in Godot 4 does not accept floats. `count * 0.5`, `count * 0.4`, and `count * 0.1` all produce floats. In Godot 4 GDScript, passing a float to `range()` raises a runtime error: `"Expected int argument for range()"`. This means `spawn_asteroids()` always crashes, so no asteroids ever appear.

```gdscript
# current — crashes at runtime
for x in range(count * 0.5):   # line 132 — float
for x in range(count * 0.4):   # line 135 — float
for x in range(count * 0.1):   # line 138 — float
```

**Fix:** Cast to int explicitly:

```gdscript
for x in range(int(count * 0.5)):
    add_asteroid(asteroids_small_model.pick_random())

for x in range(int(count * 0.4)):
    add_asteroid(asteroids_medium_model.pick_random())

for x in range(int(count * 0.1)):
    add_asteroid(asteroids_large_model.pick_random())
```

---

## Warnings

### WR-01: `mounts` cache not refreshed after `unmount_weapon()`

**File:** `components/mountable-body.gd:36-38`

**Issue:** `unmount_weapon()` calls `mount.unplug()` but does not update `self.mounts`. The stale array still references the unplugged MountPoint. Because `_physics_process` guards with `if opposite:` (line 23), there is no crash — once unplugged, `body_opposite` returns null and the branch is skipped. However, `get_mount(tag)` will still return the disconnected MountPoint for a matching tag, which means a subsequent `mount_weapon()` call to the same slot will look up a stale entry before the array is refreshed on line 34. The window is narrow but the state is inconsistent.

**Fix:** Add `mounts = get_mounts()` at the end of `unmount_weapon()`:

```gdscript
func unmount_weapon(where: String):
    var mount = get_mount(where)
    mount.unplug()
    mounts = get_mounts()   # keep cache consistent
```

---

### WR-02: `mount_weapon()` in `world.gd` does not run `setup_spawn_parent` on the mounted weapon before `body.mount_weapon()` adds it to the tree

**File:** `world.gd:141-145`

**Issue:** `setup_spawn_parent(weapon)` is called before `body.mount_weapon(weapon, where)`, which calls `mount1.plug(mount2)` → `add_child(body_opposite)`. At the point `setup_spawn_parent` runs, the weapon has not yet been added to the scene tree, so `get_children()` on nodes that only exist post-ready will not find children added during `_ready()` (e.g. timers created in `MountableWeapon._ready()`). The timers (`shot_timer`, `reload_timer`) are added in `_ready()`, which fires when the node enters the tree — after `add_child`. So `setup_spawn_parent` misses any children created in `_ready()`. Currently timers do not need `spawn_parent`, so there is no crash today. But the ordering is fragile: if any `_ready()`-created child ever needs `spawn_parent`, it will be silently missed.

**Fix:** Call `setup_spawn_parent` after `body.mount_weapon()`:

```gdscript
func mount_weapon(body: MountableBody, what: PackedScene, where: String):
    var weapon = what.instantiate() if what else null
    body.mount_weapon(weapon, where)   # adds to tree, triggers _ready()
    if weapon:
        setup_spawn_parent(weapon)     # now catches _ready()-created children too
```

---

## Info

### IN-01: `do()` override in `MountableWeapon` uses looser `Node2D` type for sender

**File:** `components/mountable-weapon.gd:79`

**Issue:** The base class `MountableBody.do()` declares `sender: MountableBody`. The override declares `_sender: Node2D` — a broader type. GDScript does not enforce Liskov substitution on signal/function parameter types, so this works at runtime. But the mismatch is misleading: callers reading the base signature expect a `MountableBody`, while the override silently accepts any `Node2D`. The parameter is also unused (`_sender`), which is correct but could confuse future editors into widening call sites.

**Fix:** Align the override signature with the base class:

```gdscript
func do(_sender: MountableBody, action: MountableBody.Action, _where: String, _meta = null):
```

---

### IN-02: Untyped `mounts` array on `MountableBody`

**File:** `components/mountable-body.gd:15`

**Issue:** `var mounts = []` is untyped. The array always holds `MountPoint` elements (set via `get_mounts()` which calls `find_children("*", "MountPoint")`). An explicit type annotation improves IDE autocompletion, enables Godot's type-checking warnings, and documents intent.

**Fix:**

```gdscript
var mounts: Array[MountPoint] = []
```

---

_Reviewed: 2026-04-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
