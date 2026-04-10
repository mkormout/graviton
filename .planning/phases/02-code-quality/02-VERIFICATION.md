---
phase: 02-code-quality
verified: 2026-04-07T00:00:00Z
status: gaps_found
score: 2/3
overrides_applied: 0
gaps:
  - truth: "Mount point lookup does not call find_children() inside _physics_process — mounts are cached and invalidated only on mount/unmount events"
    status: partial
    reason: "find_children() is correctly absent from _physics_process. However, the mounts cache is never populated for weapon instances — MountableWeapon._ready() does not call super._ready() or mounts = get_mounts(). The only place mounts is refreshed is MountableBody.mount_weapon(), which runs on the ship, not the weapon. Result: every weapon's self.mounts is always [], so get_mount('') returns null every time fire() is called, and null.do() crashes at mountable-weapon.gd:128 every time any weapon fires."
    artifacts:
      - path: "components/mountable-weapon.gd"
        issue: "_ready() at line 29 does not call super._ready() or mounts = get_mounts(). self.mounts remains [] for all weapon instances."
      - path: "components/mountable-body.gd"
        issue: "No _ready() defined — so the base class never auto-populates mounts on node entry. mounts stays [] until mount_weapon() is called on that same node."
    missing:
      - "Add `func _ready() -> void: mounts = get_mounts()` to MountableBody so every MountableBody instance (ships and weapons alike) caches its own MountPoint children when it enters the scene tree."
      - "OR: add `mounts = get_mounts()` inside MountableWeapon._ready() after the existing timer setup, ensuring the weapon's own '' MountPoint is present in the array before fire() is ever called."
---

# Phase 2: Code Quality — Verification Report

**Phase Goal:** Fragile patterns that cause silent failures and excess CPU cost are replaced with robust alternatives
**Verified:** 2026-04-07T00:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Action dispatch uses typed constants — a typo in an action name produces a GDScript error or warning, not silent failure | VERIFIED | `enum Action { FIRE, RELOAD, RECOIL, GODMODE, USE_AMMO, USE_RATE }` present in mountable-body.gd:4-11. All do() signatures use `action: Action` or `action: MountableBody.Action`. All call sites in world.gd use `MountableBody.Action.FIRE` etc. No raw string literals remain in any do() or notify_weapons() call across all 4 files. |
| 2 | Mount point lookup does not call find_children() inside _physics_process — mounts are cached and invalidated only on mount/unmount events | PARTIAL / FAILED | find_children() is correctly removed from get_mount() and absent from _physics_process. However, the mounts cache is never populated for weapon instances: MountableWeapon._ready() does not call super._ready() or mounts = get_mounts(). self.mounts remains [] for every weapon, so get_mount("") returns null inside fire() (line 127), and null.do() at line 128 crashes every time any weapon fires. The fix is incomplete — it removed the hot-path scene-tree walk but broke the fallback that previously made it work. |
| 3 | No print() calls fire during normal drag-and-drop interactions in the inventory UI | VERIFIED | inventory-slot.gd contains no print() calls. _get_drag_data returns data correctly and the function body is intact. |

**Score:** 2/3 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `components/mountable-body.gd` | Action enum definition + typed do() signature | VERIFIED | enum Action at line 4, do() with `action: Action` at line 40, Action.RECOIL comparison at line 44, for mount in mounts: at line 58 (plan 01 fix preserved) |
| `components/mountable-weapon.gd` | typed do() override + Action.RECOIL call site | VERIFIED (with defect) | do() uses `action: MountableBody.Action` at line 79; Action.RECOIL at line 128. But mounts never populated — null crash at line 128 on every fire. |
| `components/mount-point.gd` | typed do() passthrough signature | VERIFIED | do() at line 68 uses `action: MountableBody.Action` |
| `world.gd` | typed notify_weapons() + enum call sites | VERIFIED | notify_weapons() at line 53 uses `action: MountableBody.Action`; 4x MountableBody.Action.FIRE, plus GODMODE, USE_AMMO, USE_RATE, RELOAD |
| `components/inventory-slot.gd` | print removal | VERIFIED | No print() calls present; _get_drag_data intact and returns data |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| world.gd:notify_weapons() | MountableBody.do() | $ShipBFG23.do(null, action, ...) | VERIFIED | Pattern `action: MountableBody\.Action` present; call sites use enum variants |
| components/mountable-weapon.gd:fire() | MountPoint.do() | mount.do(self, Action.RECOIL, recoil) | BROKEN | Pattern present at line 128, but get_mount("") at line 127 always returns null (mounts array is empty on weapon instances) — null.do() crashes at runtime |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — Godot GDScript cannot be executed headlessly without the editor. File-level static analysis used instead; the null-crash at mountable-weapon.gd:128 was identified through code inspection (get_mount("") on an empty mounts array).

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| QUA-01 | 02-02-PLAN.md | Action dispatch uses typed constants instead of raw string literals | SATISFIED | enum Action defined; all 4 files updated; no string literals in do() calls |
| QUA-02 | 02-01-PLAN.md | Mount point lookup is cached — find_children() not called every physics frame | PARTIALLY SATISFIED | find_children() removed from hot path; cache correctly used in _physics_process iteration. But cache is never seeded for weapon instances — the fix is incomplete and introduces a crash on fire. |
| QUA-03 | 02-01-PLAN.md | Debug print() removed from inventory drag-and-drop hot path | SATISFIED | No print() in inventory-slot.gd |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| components/mountable-weapon.gd | 127-128 | `var mount = get_mount("") \ mount.do(...)` with mounts always [] | Blocker | null.do() crash every time any weapon fires — game is unplayable |
| components/mountable-weapon.gd | 44 | `get_mount()` in get_ship() — same empty mounts problem | Warning | get_ship() always returns null; any code path using it silently fails |
| world.gd | 132,135,138 | `range(count * 0.5)` etc — float argument to range() | Warning | Pre-existing bug (CR-02), not introduced by phase 2; spawn_asteroids() crashes in Godot 4 |

---

## Human Verification Required

None. All items were verifiable through static code inspection.

---

## Gaps Summary

One blocker gap prevents full goal achievement for SC-2.

**Root cause:** The QUA-02 cache fix correctly eliminated `find_children()` from the per-frame path, but left the cache initialization incomplete. `MountableBody` has no `_ready()` to seed `mounts` on enter-tree. `mount_weapon()` on the parent ship refreshes the ship's `mounts`, but weapons are never on the receiving end of this call — they are the argument, not the caller. So every `MountableWeapon` instance enters the scene tree with `mounts = []` and it stays empty.

The immediate consequence: `fire()` calls `get_mount("")` on `self` (the weapon) to find the weapon's own root MountPoint for recoil dispatch. With `mounts = []`, `get_mount("")` returns null. `null.do(self, Action.RECOIL, recoil)` is a GDScript null-instance call — a runtime crash. This fires every time a weapon is fired. The game cannot fire any weapon without crashing.

**Fix required (minimal):** Add `_ready()` to `MountableBody` that calls `mounts = get_mounts()`, or add `mounts = get_mounts()` inside `MountableWeapon._ready()` after the existing timer setup. Either approach ensures the weapon's own MountPoint child is cached before `fire()` is ever called. The code review (CR-01) documents this fix precisely.

---

_Verified: 2026-04-07_
_Verifier: Claude (gsd-verifier)_
