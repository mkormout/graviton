---
phase: 02-code-quality
plan: 01
subsystem: core-components
tags: [performance, cleanup, mount-system, inventory]
dependency_graph:
  requires: []
  provides: [get_mount-cache-fix, inventory-slot-print-removal]
  affects: [components/mountable-body.gd, components/inventory-slot.gd]
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - components/mountable-body.gd
    - components/inventory-slot.gd
decisions: []
requirements_closed: [QUA-02, QUA-03]
metrics:
  duration: ~3 minutes
  completed: 2026-04-07
  tasks_completed: 2
  files_modified: 2
---

# Phase 02 Plan 01: Mount Cache Fix and Print Removal Summary

**One-liner:** Eliminated per-frame `find_children()` scene-tree walk in `get_mount()` by iterating the pre-populated `mounts` array, and removed noisy drag-and-drop debug print from `inventory-slot.gd`.

## What Was Done

### Task 1 — Fix get_mount() to iterate mounts cache (QUA-02)

`get_mount()` previously called `get_mounts()` (which calls `find_children("*", "MountPoint")`) on every call. Since `get_mount()` is called from `_physics_process` and `do()`, this triggered a full scene-tree walk every physics frame (60+ times/second).

Changed the `for` loop in `get_mount()` from `get_mounts()` to `mounts` — the array already populated by `mount_weapon()` on mount events. `get_mounts()` / `find_children()` now only runs during weapon mount/unmount, not on the hot path.

- **File:** `components/mountable-body.gd`
- **Commit:** 3761538

### Task 2 — Remove debug print from inventory-slot drag hot path (QUA-03)

Removed `print("_get_drag_data: ", data)` from `_get_drag_data()`. This fired every time the player initiated a drag operation in the inventory UI. No replacement needed — it was a development debug statement.

- **File:** `components/inventory-slot.gd`
- **Commit:** c223602

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. Pure internal GDScript edits with no network, auth, PII, or external input surface.

## Self-Check: PASSED

- `components/mountable-body.gd` — modified, committed at 3761538
- `components/inventory-slot.gd` — modified, committed at c223602
- `grep "for mount in mounts:" components/mountable-body.gd` — 1 result (PASS)
- `grep "for mount in get_mounts():" components/mountable-body.gd` — 0 results (PASS)
- `grep "mounts = get_mounts()" components/mountable-body.gd` — 1 result at line 25 (PASS)
- `grep "print" components/inventory-slot.gd` — 0 results (PASS)
