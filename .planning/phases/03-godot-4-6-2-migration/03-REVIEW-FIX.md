---
phase: 03-godot-4-6-2-migration
fixed_at: 2026-04-10T21:52:42Z
review_path: .planning/phases/03-godot-4-6-2-migration/03-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-04-10T21:52:42Z
**Source review:** .planning/phases/03-godot-4-6-2-migration/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (3 Critical, 4 Warning)
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01: Null dereference on `attack` in Bullet.collision

**Files modified:** `components/bullet.gd`
**Commit:** 9f01af4
**Applied fix:** Wrapped `body.damage(attack)` in an `if attack:` guard; added `push_warning` when `attack` is unset, so a misconfigured bullet warns instead of crashing on every collision.

---

### CR-02: Null dereference on `mount.do()` after `get_mount("")` in MountableWeapon.fire

**Files modified:** `components/mountable-weapon.gd`
**Commit:** f5bc39f
**Applied fix:** Wrapped `mount.do(self, Action.RECOIL, recoil)` in `if mount:` guard so weapons without an empty-tagged mount point no longer crash on every shot.

---

### CR-03: Invalid Apple bundle identifier — `com.apple.quarantine`

**Files modified:** `export_presets.cfg`
**Commit:** c8162ee
**Applied fix:** Replaced `com.apple.quarantine` with `com.mkormout.graviton` — a valid project-specific reverse-domain identifier that will not conflict with Apple's reserved namespace or trigger quarantine attribute behavior.

---

### WR-01: Signal-ordering race in MountPoint.unplug — body_opposite may become null during slot notification

**Files modified:** `components/mount-point.gd`
**Commit:** 7759b20
**Applied fix:** Cached `body_opposite` into a local variable `departing_body` before emitting `unplugging` and before any other signal handler can clear `connection`. All subsequent uses within `unplug()` (impulse, reparent, queue_free, slot decrement lambda) now reference the cached local. Also improved the `free` check from `if free and body_opposite:` to `if free and is_instance_valid(departing_body):` to handle the case where the node was freed by a signal handler.

---

### WR-02: Null guard missing on `ammo` and `barrel` exports in MountableWeapon.fire

**Files modified:** `components/mountable-weapon.gd`
**Commit:** 51db4f8
**Applied fix:** Added an early-return guard at the top of `fire()` that checks `if not ammo or not barrel:` and emits a `push_warning` naming the weapon. Prevents a crash when a weapon is placed in the scene without its required resources configured in the inspector.

---

### WR-03: Dead raycast in Ship._on_body_entered — result never used

**Files modified:** `components/ship.gd`
**Commit:** 47a70c9
**Applied fix:** Removed the 6-line `RayCast2D` block (create, add_child, force_raycast_update, get_collision_point, queue_free) that produced an unused `contact_point`. The damage calculation that followed it (`speed / 10.0`) was already correct and remains intact. This also resolves IN-03 (unused `contact_point` variable) as a side effect.

---

### WR-04: Silent match failure in Ship.picker_body_entered — unknown item types ignored

**Files modified:** `components/ship.gd`
**Commit:** 21cb740
**Applied fix:** Added a `_:` default arm to the `match item.type.type` block that calls `push_warning` with the unhandled type name. Future item types (e.g., `FUEL`, `SHIELD`) will now surface a visible warning rather than silently discarding the picked-up item.

---

_Fixed: 2026-04-10T21:52:42Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
