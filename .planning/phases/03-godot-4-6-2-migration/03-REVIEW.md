---
phase: 03-godot-4-6-2-migration
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - components/bullet.gd
  - components/mount-point.gd
  - components/mountable-weapon.gd
  - components/ship.gd
  - export_presets.cfg
  - project.godot
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-10
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Review covers the four core GDScript components (`bullet.gd`, `mount-point.gd`, `mountable-weapon.gd`, `ship.gd`) plus the engine configuration files (`project.godot`, `export_presets.cfg`), targeting the Godot 4.6.2 migration milestone.

Three critical issues were found: a null dereference on `attack` in `bullet.gd` that crashes on any bullet-to-body hit when the export is unset; a missing null guard on `get_mount("")` in `mountable-weapon.gd` that crashes on every `fire()` call for weapons without a tagged mount; and an invalid Apple bundle identifier in `export_presets.cfg` that will cause macOS distribution to fail. Four warnings cover a signal-ordering race in `unplug()`, an unused raycast in `ship.gd`, missing null guards on exported scene/node references in `mountable-weapon.gd`, and a silent-failure match with no default case. Three info items cover placeholder Android identifiers, a dead `_connection_tree_exiting` connection check, and an unused local variable.

---

## Critical Issues

### CR-01: Null dereference on `attack` in Bullet.collision

**File:** `components/bullet.gd:14`
**Issue:** `attack` is an `@export var attack: Damage`. If the export property is not assigned in the Godot inspector, `attack` is `null`. The call `body.damage(attack)` passes `null` to `Body.damage()`, which will crash if that method dereferences the argument without a null check. Every bullet-to-body collision hits this path.
**Fix:**
```gdscript
func collision(body):
    if body is Body:
        if attack:
            body.damage(attack)
        else:
            push_warning("Bullet %s has no attack resource assigned" % name)
    die(death_ttl)
```

---

### CR-02: Null dereference on `mount.do()` after `get_mount("")` in MountableWeapon.fire

**File:** `components/mountable-weapon.gd:127-128`
**Issue:** `get_mount("")` returns the first `MountPoint` with an empty tag, or `null` if none exists. The return value is assigned to `mount` with no null check, and then `mount.do(...)` is called immediately after. A weapon that has no mount with an empty tag (e.g., a standalone weapon or one with only named mounts) will crash on every shot.
**Fix:**
```gdscript
var mount = get_mount("")
if mount:
    mount.do(self, Action.RECOIL, recoil)
```

---

### CR-03: Invalid Apple bundle identifier — `com.apple.quarantine`

**File:** `export_presets.cfg:684`
**Issue:** The macOS preset uses `application/bundle_identifier="com.apple.quarantine"`. The string `com.apple.quarantine` is the name of a macOS security quarantine attribute, not a valid bundle identifier. Apple reserves the `com.apple.*` namespace; submitting or distributing a build with this identifier will be rejected by notarization and the App Store, and may produce unexpected behavior from macOS security APIs.
**Fix:** Replace with a project-specific reverse-domain identifier:
```ini
application/bundle_identifier="com.yourname.graviton"
```

---

## Warnings

### WR-01: Signal-ordering race in MountPoint.unplug — body_opposite may become null during slot notification

**File:** `components/mount-point.gd:49-57`
**Issue:** `unplugging.emit(self, connection)` is called on line 49 before `connection` is cleared (line 60). If any signal handler connected to `unplugging` calls `unplug()` again or clears `connection` directly, the `call_slots` lambda on line 55–57 will call `body_opposite.item_type` where `body_opposite` is now null (because `get_body_opposite()` reads `connection`). This is a null-dereference crash triggered by re-entrant signal handling.
**Fix:** Cache `body_opposite` before emitting the signal, then use the cached reference in the lambda:

```gdscript
func unplug(free: bool = false):
    if connection:
        var departing_body = body_opposite  # cache before any signal

        departing_body.apply_central_impulse(
            Vector2.from_angle(departing_body.rotation) * throw_force
        )
        if spawn_parent:
            departing_body.reparent(spawn_parent)
        else:
            push_warning("spawn_parent not set on " + name)

        unplugging.emit(self, connection)

        if free and is_instance_valid(departing_body):
            departing_body.queue_free()

        call_slots(func(slot: InventorySlot):
            slot.dec(departing_body.item_type)
        )

    connection = null
```

---

### WR-02: Null guard missing on `ammo` and `barrel` exports in MountableWeapon.fire

**File:** `components/mountable-weapon.gd:103-104`
**Issue:** `ammo.instantiate()` on line 103 crashes if `ammo` (a `@export var ammo: PackedScene`) was not assigned in the inspector. Similarly, `barrel.global_position` on line 104 crashes if `barrel` is null. Both are required for the weapon to function. A missing assignment silently reaches these lines with no warning.
**Fix:** Add guards at the start of `fire()`:
```gdscript
func fire():
    if not ammo or not barrel:
        push_warning("MountableWeapon %s: ammo or barrel not configured" % name)
        return
    # ... rest of fire()
```

---

### WR-03: Dead raycast in Ship._on_body_entered — result never used

**File:** `components/ship.gd:38-43`
**Issue:** A `RayCast2D` is created, added to the scene tree, force-updated, and immediately freed, but the returned `contact_point` (line 42) is never referenced again. The raycast costs a physics query per collision with no effect. This is dead code that may have been intended to compute a collision normal or contact-point-based damage, but the calculation result is discarded.
**Fix:** Remove lines 38–43 if contact-point information is not needed. If it was meant to scale damage by angle of impact, wire `contact_point` into the damage calculation:
```gdscript
func _on_body_entered(body):
    var speed = body.linear_velocity.length() if body is RigidBody2D else 0.0
    var attack = Damage.new()
    attack.kinetic = speed / 10.0
    damage(attack)
```

---

### WR-04: Silent match failure in Ship.picker_body_entered — unknown item types ignored

**File:** `components/ship.gd:59-63`
**Issue:** The `match item.type.type` block handles `COIN`, `AMMO`, `WEAPON`, and `HEALTH` but has no default arm. If a new `ItemTypes` value is added (e.g., `FUEL`, `SHIELD`), pickup silently does nothing — no warning, no item added to inventory. Items vanish from the world without feedback.
**Fix:** Add a default arm with a warning:
```gdscript
match item.type.type:
    IT.ItemTypes.COIN: pick_coin(item)
    IT.ItemTypes.AMMO: pick_ammo(item)
    IT.ItemTypes.WEAPON: pick_weapon(item)
    IT.ItemTypes.HEALTH: pick_health(item)
    _:
        push_warning("Ship: unhandled item type %s" % item.type.type)
```

---

## Info

### IN-01: Placeholder Android bundle identifiers in both Android presets

**File:** `export_presets.cfg:174` and `export_presets.cfg:408`
**Issue:** Both Android presets (Debug and Release) use `package/unique_name="org.godotengine.$genname"`, which is the Godot default template placeholder. Publishing to Google Play requires a unique reverse-domain identifier. This will fail at Play Store submission.
**Fix:** Set a real identifier before distribution:
```ini
package/unique_name="com.yourname.graviton"
```

---

### IN-02: `_connection_tree_exiting` is defined but connection to signal is not visible in code

**File:** `components/mount-point.gd:77-78`
**Issue:** `_connection_tree_exiting()` calls `unplug()` and is presumably meant to fire when the connected body's node exits the scene tree. However, the signal connection to `connection.tree_exiting` is not established in `_ready()` or `plug()` in this file. If the wiring exists only in the scene editor, it is fragile (adding a mount point programmatically will miss it). If it is connected in `plug()` elsewhere, that code was not in scope.

Verify that `plug()` connects `other.get_parent().tree_exiting.connect(_connection_tree_exiting)` and that `unplug()` disconnects it. If not, the safeguard against dangling connections is inactive.

---

### IN-03: Unused `contact_point` local variable in Ship._on_body_entered

**File:** `components/ship.gd:42`
**Issue:** `var contact_point = ray.get_collision_point()` is assigned but never read. In strict-mode GDScript projects this may generate a warning. Combined with WR-03, removing the entire raycast block eliminates this.

---

_Reviewed: 2026-04-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
