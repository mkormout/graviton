---
phase: 02-code-quality
created: 2026-04-07
requirements: QUA-01, QUA-02, QUA-03
---

# Phase 2: Code Quality — Context

## Scope

Eliminate three fragile patterns that cause silent failures and wasted CPU:
- **QUA-01**: Raw string action literals → typed enum
- **QUA-02**: `find_children()` per physics frame → cached mount array
- **QUA-03**: Debug `print()` in drag-and-drop hot path → removed

No new gameplay features. No refactoring beyond these three requirements.

## Canonical Refs

- `.planning/REQUIREMENTS.md` — QUA-01, QUA-02, QUA-03 acceptance criteria
- `components/mountable-body.gd` — owns `do()`, `get_mount()`, `get_mounts()`, `mounts` cache
- `components/mountable-weapon.gd` — `do()` handler, dispatches `"recoil"` via mount
- `components/mount-point.gd` — `do()` passthrough
- `world.gd` — all `notify_weapons()` and direct `.do()` call sites
- `components/inventory-slot.gd` — contains the hot-path `print()`

## Decisions

### QUA-01: Action dispatch — Enum in MountableBody

**Decision:** Define `enum Action { FIRE, RELOAD, RECOIL, GODMODE, USE_AMMO, USE_RATE }` as an inner enum in `MountableBody`. Change all `do()` signatures from `action: String` to `action: MountableBody.Action` (or `Action` within the same file). GDScript type-checks enum values at parse time — a wrong value is a compile error.

**Scope of changes:**
- `mountable-body.gd`: Add enum, change `do()` signature, update `if action ==` comparisons to use `Action.RECOIL` etc.
- `mountable-weapon.gd`: Change `do()` signature, update `if action ==` comparisons, change `mount.do(self, "recoil", ...)` to `mount.do(self, Action.RECOIL, ...)`
- `mount-point.gd`: Change `do()` signature (it's a passthrough — just the signature changes)
- `world.gd`: Change all `notify_weapons("fire")` etc. to `notify_weapons(MountableBody.Action.FIRE)` and update `notify_weapons()` + direct `.do()` calls accordingly

**Rationale:** String constants satisfy neither the requirement (typos still fail silently at runtime) nor the success criterion ("produces a GDScript error or warning"). Only an enum with a typed parameter achieves true compile-time safety.

---

### QUA-02: Mount cache — Minimal fix

**Decision:** Change `get_mount(tag: String)` to iterate the existing `mounts: Array` variable instead of calling `find_children("*", "MountPoint")`. The `mounts` array is already populated correctly by `mount_weapon()`.

**Scope:** One change in `mountable-body.gd:get_mount()`. Do NOT refactor `get_mounts()` further — it is only called by `mount_weapon()` (on mount events, not per-frame), so it is not a hot path concern.

**Note on unmount invalidation:** `unmount_weapon()` calls `mount.unplug()` but does not refresh `mounts`. This is a pre-existing gap, but fixing it is out of scope for this phase — the requirement is specifically about `find_children()` in the per-frame path. If stale mount entries cause issues during testing, update `unmount_weapon()` to call `mounts = get_mounts()` as a contained fix.

---

### QUA-03: Debug print removal

**Decision:** Remove `print("_get_drag_data: ", data)` from `components/inventory-slot.gd:71`. Single line deletion. No replacement needed — this was a development debug statement.

## Implementation Notes

- The `do()` signature change touches multiple files but is mechanical — find all `do(` call sites and update the action argument from a string literal to the enum variant.
- `notify_weapons(action: String)` in `world.gd` should also be updated to `notify_weapons(action: MountableBody.Action)` for consistency.
- GDScript enum variants are integers under the hood — existing `if action ==` comparisons work identically after the type change, just with enum values instead of strings.
- The `where: String` parameter in `do()` remains a String (it identifies mount slots by name tag — a different concern from action dispatch).
