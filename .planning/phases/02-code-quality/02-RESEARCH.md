# Phase 2: Code Quality — Research

**Researched:** 2026-04-07
**Domain:** GDScript refactoring — enum dispatch, cache invalidation, debug-print removal
**Confidence:** HIGH

## Summary

Phase 2 targets three narrow, mechanical changes. All three requirements are fully bounded by the existing codebase: no new scenes, no new nodes, no external dependencies. The changes are surgical and the call graph is fully mapped. Nothing requires web research or library discovery — the domain is pure GDScript.

QUA-01 replaces 6 string-literal action arguments (and 5 `if action ==` comparisons) with a typed inner enum. The change is mechanical but touches 4 files. QUA-02 changes one line in `get_mount()` to iterate the pre-existing `mounts` array instead of calling `find_children()`. QUA-03 deletes one `print()` line. All three changes are fully verifiable by code inspection.

**Primary recommendation:** Execute the three changes in order of risk — QUA-03 (trivial deletion), QUA-02 (one-line fix), QUA-01 (multi-file enum refactor).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**QUA-01:** Define `enum Action { FIRE, RELOAD, RECOIL, GODMODE, USE_AMMO, USE_RATE }` as an inner enum in `MountableBody`. Change all `do()` signatures from `action: String` to `action: MountableBody.Action`. Update all `if action ==` comparisons to use enum variants. Update `notify_weapons()` in `world.gd` to `notify_weapons(action: MountableBody.Action)`.

**QUA-02:** Change `get_mount(tag: String)` to iterate the existing `mounts: Array` variable instead of calling `find_children()`. Do NOT refactor `get_mounts()` — it is only called on mount events, not per-frame. If stale entries surface during testing, allow adding `mounts = get_mounts()` to `unmount_weapon()` as a contained fix.

**QUA-03:** Delete `print("_get_drag_data: ", data)` at `components/inventory-slot.gd:71`. No replacement.

### Claude's Discretion

None stated — all decisions locked.

### Deferred Ideas (OUT OF SCOPE)

- Full unmount invalidation refactor beyond the `mounts` cache (pre-existing gap, out of scope)
- Any gameplay features
- Any refactoring beyond the three named requirements
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUA-01 | Action dispatch uses typed constants instead of raw string literals ("fire", "reload", etc.) | Enum definition site: `mountable-body.gd:31`. All call sites mapped — see Call Graph below. |
| QUA-02 | Mount point lookup is cached or event-driven — `find_children()` not called every physics frame | The `mounts` array is already populated by `mount_weapon()`. `get_mount()` at line 48 is the sole hot-path offender. |
| QUA-03 | Debug `print()` statements removed from production hot paths (inventory drag-and-drop) | Single offending line: `inventory-slot.gd:71`. |
</phase_requirements>

---

## Standard Stack

No external libraries. This phase uses only GDScript and Godot 4.2.1 built-ins.

| Construct | Version | Purpose |
|-----------|---------|---------|
| GDScript inner enum | Godot 4.x | Type-safe action constants with compile-time checking |
| `Array` iteration (`for x in array`) | Godot 4.x | Cache-based `get_mount()` implementation |

**Installation:** None required.

---

## Architecture Patterns

### QUA-01: Inner Enum in MountableBody

GDScript supports inner enums declared with `enum Name { VALUE, ... }` inside a `class_name` script. [VERIFIED: codebase — `InventorySlot` already uses `enum ItemSlotType { STORAGE, WEAPON, ... }` at `components/inventory-slot.gd:3`]

Enum values in GDScript are integers at runtime. The `if action ==` comparisons in `do()` require no structural change — only the compared values change from strings to enum integers. [VERIFIED: codebase — existing `if action == "fire"` pattern confirmed at `mountable-weapon.gd:80`]

When referencing an inner enum from outside the class, the syntax is `MountableBody.Action.FIRE`. From within the same file, `Action.FIRE` suffices. [ASSUMED — standard GDScript inner enum access pattern; confirmed by analogy with `IT.ItemTypes.COIN` usage at `ship.gd:60` which accesses an inner-class enum from a different file via a preloaded reference]

The `do()` function in `MountableBody` has a different signature from the `do()` in `MountableWeapon` — the weapon overrides `_sender` and `_where` as unused params. Both signatures must be updated to use `action: MountableBody.Action`. In `MountableWeapon.do()` the sender type is `Node2D`, not `MountableBody`, which must be preserved. [VERIFIED: codebase — `mountable-weapon.gd:79` shows `func do(_sender: Node2D, action: String, _where: String, _meta = null)`]

**Anti-pattern to avoid:** Do not define action string constants (`const ACTION_FIRE = "fire"`). The user explicitly rejected this — it satisfies neither the success criterion (typos still fail silently at parse time) nor the GDScript type system. [VERIFIED: CONTEXT.md decision rationale]

### QUA-02: Cache-Based get_mount()

The `mounts` array is already populated: `mounts = get_mounts()` is called at the end of `mount_weapon()`. [VERIFIED: codebase — `mountable-body.gd:25`]

`get_mount()` currently calls `get_mounts()` → `find_children()` on every invocation. [VERIFIED: codebase — `mountable-body.gd:48-53`]

The fix: replace `for mount in get_mounts():` with `for mount in mounts:`. This eliminates the scene-tree walk from the per-frame path. [VERIFIED: codebase — `mountable-body.gd:8-17` shows `_physics_process` iterates `mounts`, confirming this array is the right source]

`get_mounts()` itself does NOT need changing — its only caller is `mount_weapon()` which runs on mount events, not per-frame. [VERIFIED: codebase — grep confirms single call site at `mountable-body.gd:25`]

### QUA-03: Print Removal

The `print()` at `inventory-slot.gd:71` fires every time the player begins a drag on any inventory slot — `_get_drag_data` is a Godot virtual method called every drag initiation. [VERIFIED: codebase — `inventory-slot.gd:57-72`]

---

## Complete Call Graph (QUA-01)

All files containing `do()` definitions or call sites that must be updated:

### Files with `func do()` definitions (3 files, 3 functions):

| File | Line | Current Signature | Change Required |
|------|------|------------------|-----------------|
| `components/mountable-body.gd` | 31 | `func do(sender: MountableBody, action: String, where: String, meta = null)` | `action: MountableBody.Action` |
| `components/mount-point.gd` | 68 | `func do(sender: MountableBody, action: String, meta = null)` | `action: MountableBody.Action` |
| `components/mountable-weapon.gd` | 79 | `func do(_sender: Node2D, action: String, _where: String, _meta = null)` | `action: MountableBody.Action` |

### Files with `do()` call sites passing string literals (2 files, 6 call sites):

| File | Line | Current Call | Change Required |
|------|------|-------------|-----------------|
| `world.gd` | 57-59 | `$ShipBFG23.do(null, action, "")` etc. | `action` param type updated via `notify_weapons` signature |
| `world.gd` | 71 | `$ShipBFG23.do(null, "fire", "left")` | `MountableBody.Action.FIRE` |
| `world.gd` | 73 | `$ShipBFG23.do(null, "fire", "")` | `MountableBody.Action.FIRE` |
| `world.gd` | 75 | `$ShipBFG23.do(null, "fire", "right")` | `MountableBody.Action.FIRE` |
| `components/mountable-weapon.gd` | 128 | `mount.do(self, "recoil", recoil)` | `Action.RECOIL` (within MountableBody subclass) |
| `world.gd` | 53 | `func notify_weapons(action: String)` | `action: MountableBody.Action` |

### Indirect call sites in world.gd via notify_weapons (6 string literals):

| Line | Current | Change Required |
|------|---------|-----------------|
| 64 | `notify_weapons("fire")` | `notify_weapons(MountableBody.Action.FIRE)` |
| 101 | `notify_weapons("godmode")` | `notify_weapons(MountableBody.Action.GODMODE)` |
| 105 | `notify_weapons("use_ammo")` | `notify_weapons(MountableBody.Action.USE_AMMO)` |
| 108 | `notify_weapons("use_rate")` | `notify_weapons(MountableBody.Action.USE_RATE)` |
| 111 | `notify_weapons("reload")` | `notify_weapons(MountableBody.Action.RELOAD)` |

### `if action ==` comparisons (5 comparisons in 2 files):

| File | Lines | Current | Change Required |
|------|-------|---------|-----------------|
| `mountable-body.gd` | 35 | `if action == "recoil"` | `if action == Action.RECOIL` |
| `mountable-weapon.gd` | 80, 83, 86, 89, 92 | `if action == "fire"` etc. | `Action.FIRE`, `Action.RELOAD`, `Action.GODMODE`, `Action.USE_AMmo`, `Action.USE_RATE` |

### Files confirmed NOT affected:

- `prefabs/gravitygun/gravitygun-script.gd` — overrides `fire()` directly, does not override or call `do()` [VERIFIED: codebase]
- `components/ship.gd` — extends `MountableBody`, does not override or call `do()` [VERIFIED: codebase]
- `components/player-ship.gd` — not inspected, check for any `do()` calls
- `components/enemy-ship.gd` — not inspected, check for any `do()` calls

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Type-safe action dispatch | String constants with runtime guards | GDScript inner enum | Enum gives compile-time type checking; string constants still allow typo-prone assignments |
| Scene-tree cache | Custom observer/event system for mount tracking | Existing `mounts` array (already populated) | `mounts` is already maintained by `mount_weapon()` — no new mechanism needed |

---

## Common Pitfalls

### Pitfall 1: Forgetting MountPoint.do() signature
**What goes wrong:** `mount-point.gd:do()` is a passthrough — its `action` parameter must also be typed as `MountableBody.Action`, or GDScript will fail to pass the enum value through the chain.
**Why it happens:** `mount-point.gd` does not define or inspect the action value, so it's easy to overlook.
**How to avoid:** Update all three `func do()` definitions together as a single step.

### Pitfall 2: world.gd references MountableBody without a preload
**What goes wrong:** `world.gd` has no explicit `class_name` and doesn't import `MountableBody`. Writing `MountableBody.Action.FIRE` may fail if `MountableBody` is not in scope.
**Why it happens:** `world.gd` uses `extends Node2D` with no preload of `MountableBody`. GDScript resolves globally registered class names (via `class_name`) without explicit imports. [ASSUMED — GDScript `class_name` creates a global autocompletion identifier; this is standard Godot 4 behavior; verify in editor after change]
**How to avoid:** After making the change, open Godot editor and confirm no parser errors on `world.gd`.
**Warning signs:** Editor shows "Identifier 'MountableBody' not found" in `world.gd`.

### Pitfall 3: Stale mounts array after unmount
**What goes wrong:** After `unmount_weapon()` is called, the `mounts` array retains the old `MountPoint` reference. `get_mount()` will iterate a stale entry.
**Why it happens:** `unmount_weapon()` calls `mount.unplug()` but does not update `mounts`. [VERIFIED: codebase — `mountable-body.gd:27-29`]
**How to avoid:** Per CONTEXT.md decision: this is a pre-existing gap and out of scope. If it surfaces during testing, add `mounts = get_mounts()` to `unmount_weapon()` as a contained fix. The contained fix is permitted by the locked decision.
**Warning signs:** After pressing A/S/D (unmount keys), firing causes a null-reference error or fires at a stale mount.

### Pitfall 4: player-ship.gd or enemy-ship.gd with undiscovered do() calls
**What goes wrong:** If `player-ship.gd` or `enemy-ship.gd` call `do()` with string literals and are not updated, they become runtime failures.
**Why it happens:** These files were not checked during research (grep covers `.gd` files but the files should be verified for `do()` call sites).
**How to avoid:** Planner must include a grep step or file read of `player-ship.gd` and `enemy-ship.gd` before execution to confirm no additional call sites. See Open Questions.

---

## Code Examples

### Inner enum declaration (QUA-01)
```gdscript
# Source: codebase analogy — inventory-slot.gd:3 uses same pattern
class_name MountableBody
extends Body

enum Action {
    FIRE,
    RELOAD,
    RECOIL,
    GODMODE,
    USE_AMMO,
    USE_RATE
}

# Updated do() signature
func do(sender: MountableBody, action: Action, where: String, meta = null):
    if action == Action.RECOIL:
        ...
```

### Cross-file enum reference (QUA-01)
```gdscript
# In world.gd — MountableBody is a globally registered class_name
func notify_weapons(action: MountableBody.Action):
    $ShipBFG23.do(null, action, "")
    $ShipBFG23.do(null, action, "left")
    $ShipBFG23.do(null, action, "right")

# Call site
notify_weapons(MountableBody.Action.FIRE)
```

### Cache-based get_mount() (QUA-02)
```gdscript
# Before (hot path — calls find_children every invocation)
func get_mount(tag: String = "") -> MountPoint:
    for mount in get_mounts():   # get_mounts() calls find_children()
        if mount.tag == tag:
            return mount
    return null

# After (uses pre-populated cache)
func get_mount(tag: String = "") -> MountPoint:
    for mount in mounts:
        if mount.tag == tag:
            return mount
    return null
```

### Print removal (QUA-03)
```gdscript
# Before (inventory-slot.gd:57-73)
func _get_drag_data(_at_position: Vector2) -> Variant:
    var data = null
    if occupant:
        data = { "source": self, "item_type": occupant, "quantity": quantity }
        set_drag_preview(make_drag_preview())
    print("_get_drag_data: ", data)   # DELETE THIS LINE
    return data

# After
func _get_drag_data(_at_position: Vector2) -> Variant:
    var data = null
    if occupant:
        data = { "source": self, "item_type": occupant, "quantity": quantity }
        set_drag_preview(make_drag_preview())
    return data
```

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GDScript `class_name` declarations are globally accessible without explicit import — `MountableBody.Action.FIRE` will resolve in `world.gd` without a preload | Pitfall 2, Code Examples | If wrong, `world.gd` needs a `const MB = preload("res://components/mountable-body.gd")` and all references become `MB.Action.FIRE` |
| A2 | `player-ship.gd` and `enemy-ship.gd` contain no `do()` call sites | Call Graph | If wrong, those files need additional string→enum updates |

---

## Open Questions

1. **Do player-ship.gd and enemy-ship.gd have do() call sites?**
   - What we know: Grep of all `.gd` files found `do()` call sites only in `world.gd`, `mount-point.gd`, `mountable-body.gd`, and `mountable-weapon.gd`
   - What's unclear: `player-ship.gd` and `enemy-ship.gd` were not individually read
   - Recommendation: Planner should add a task in Wave 0 to read these files before executing QUA-01 changes. If they have call sites, add them to the change list.

2. **Does world.gd resolve MountableBody without a preload?**
   - What we know: `world.gd` uses `$ShipBFG23` which is a `MountableBody` descendant; GDScript class_name resolution is global
   - What's unclear: Whether the Godot 4.2.1 parser will accept `MountableBody.Action.FIRE` in `world.gd` without an explicit preload
   - Recommendation: Verify in Godot editor immediately after the change. If the error appears, add `const MountableBody = preload("res://components/mountable-body.gd")` at the top of `world.gd`.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — all changes are pure GDScript file edits within an existing Godot 4.2.1 project).

---

## Validation Architecture

nyquist_validation is explicitly `false` in `.planning/config.json`. Section skipped.

---

## Security Domain

No security domain applies to this phase. Changes are internal GDScript refactoring with no input validation, authentication, session, or cryptography concerns.

---

## Sources

### Primary (HIGH confidence — codebase verified)
- `components/mountable-body.gd` — `do()` definition, `get_mount()`, `get_mounts()`, `mounts` array, `_physics_process`
- `components/mountable-weapon.gd` — `do()` override, `mount.do(self, "recoil", ...)` call site
- `components/mount-point.gd` — `do()` passthrough
- `world.gd` — all `notify_weapons()` call sites, all direct `.do()` call sites
- `components/inventory-slot.gd` — `print()` location at line 71, `_get_drag_data` hot path
- `prefabs/gravitygun/gravitygun-script.gd` — confirmed not affected (overrides `fire()` only)
- `components/ship.gd` — confirmed not affected (no `do()` override or call)
- `.planning/phases/02-code-quality/02-CONTEXT.md` — all locked decisions

### Secondary (MEDIUM confidence)
- `components/inventory-slot.gd:3` — inner enum pattern (`enum ItemSlotType`) as analogy for QUA-01 approach

### Tertiary (LOW confidence / ASSUMED)
- A1: GDScript global class_name resolution without preload in world.gd
- A2: player-ship.gd and enemy-ship.gd contain no do() call sites

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure GDScript, no external libraries
- Architecture: HIGH — all call sites verified by grep; all file contents read
- Pitfalls: HIGH — derived from direct code inspection, one LOW-confidence assumption flagged

**Research date:** 2026-04-07
**Valid until:** Stable — changes only invalidated by new `do()` call sites in future code
