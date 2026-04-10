---
phase: quick
plan: 260410-1df
subsystem: mount-system
tags: [bug-fix, null-reference, mount-point, ready-order, regression]
---

**One-liner:** Fixed `link_slot` crash by making `get_mount()` fall back to a live scene-tree search without caching, preventing a strafing regression caused by weapon `_physics_process` running the sync loop backwards.

## What Changed
- `components/mountable-body.gd`: `get_mount()` now uses a local `search` variable for the fallback when `mounts` is empty — searches live via `get_mounts()` without writing back to `mounts`

## Root Cause
Two bugs, one fix:
1. **Crash:** `ship-bfg-23-inventory._ready()` fires before the ship's `_ready()` (Godot child-before-parent order). `ship.get_mount("")` returned null because `mounts = []`. `link_slot()` was called on null.
2. **Strafing regression (introduced by first attempt):** The initial fix used `if mounts.is_empty(): mounts = get_mounts()` — this populated the **weapon's** `mounts` as a side effect of `mount_weapon()` calling `what.get_mount("")`. The weapon's `_physics_process` then iterated its mounts and found `body_opposite = ship`, trying to teleport the ship to the weapon's position every frame.

The local-variable approach fixes the crash without the side effect: `mounts` is only ever written by `mount_weapon()` (intentional), never by `get_mount()`.

## Verification
- [x] Automated: `get_mount()` uses local `search` variable (no `mounts` write)
- [x] Human: Game launches without `link_slot in base Nil` error
- [x] Human: Left/Right rotate ship cleanly (no strafing)
- [x] Human: User confirmed everything functional
