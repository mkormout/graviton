---
phase: 02-code-quality
plan: 02
subsystem: core-components
tags: [type-safety, refactor, action-dispatch, enum]
dependency_graph:
  requires: [02-01]
  provides: [action-enum, typed-do-signatures]
  affects: [components/mountable-body.gd, components/mountable-weapon.gd, components/mount-point.gd, world.gd]
tech_stack:
  added: []
  patterns: [GDScript inner enum, typed function parameters]
key_files:
  created: []
  modified:
    - components/mountable-body.gd
    - components/mountable-weapon.gd
    - components/mount-point.gd
    - world.gd
decisions: []
requirements_closed: [QUA-01]
metrics:
  duration: ~5 minutes
  completed: 2026-04-07
  tasks_completed: 2
  files_modified: 4
---

# Phase 02 Plan 02: Action Enum Refactor Summary

**One-liner:** Replaced all raw string action literals with a typed `MountableBody.Action` inner enum across 4 files — typos in action dispatch now produce GDScript parse-time errors instead of silent no-ops.

## What Was Done

### Task 1 — Define Action enum and update do() in mountable-body.gd (QUA-01 — definition site)

Added `enum Action { FIRE, RELOAD, RECOIL, GODMODE, USE_AMMO, USE_RATE }` as an inner enum in `MountableBody`, placed after `extends Body`. Updated `do()` signature from `action: String` to `action: Action`. Replaced the `action == "recoil"` string comparison with `action == Action.RECOIL`.

- **File:** `components/mountable-body.gd`
- **Commit:** a3d140f

### Task 2 — Update all consumers: mountable-weapon.gd, mount-point.gd, world.gd (QUA-01 — consumers)

Applied enum types across all three consumer files:

- `components/mountable-weapon.gd`: `do()` signature changed to `action: MountableBody.Action`; all five `if action ==` comparisons updated to enum variants; `fire()` recoil dispatch changed from `"recoil"` string to `Action.RECOIL`.
- `components/mount-point.gd`: `do()` passthrough signature changed to `action: MountableBody.Action`; no body changes needed (pure passthrough).
- `world.gd`: `notify_weapons()` signature changed to `action: MountableBody.Action`; one `_process` call and three direct `_input` do() calls updated to `MountableBody.Action.FIRE`; four `notify_weapons()` calls updated to `GODMODE`, `USE_AMMO`, `USE_RATE`, and `RELOAD` enum variants.

Zero raw string literals remain in any `do()` call or `notify_weapons()` call across all 4 files.

- **Files:** `components/mountable-weapon.gd`, `components/mount-point.gd`, `world.gd`
- **Commit:** deb5d3a

## Deviations from Plan

**Working tree state on entry:** The worktree was initialized via `git reset --soft` which preserved an older working tree. The working files for `mountable-weapon.gd`, `mount-point.gd`, and `world.gd` reflected a more recent state from the main branch (including phase-01 bug fixes: reload signal fix, spawn_parent propagation). Used `git checkout HEAD --` to restore the files to the plan 01 state before applying plan 02 changes. The extra bug fixes already present in the working tree were preserved as-is since they were correct and already committed on main.

No plan logic deviations — all changes applied exactly as specified.

## Known Stubs

None.

## Threat Flags

None. Pure internal GDScript type refactor — no network, auth, PII, or external input surface changes. The action dispatch system now accepts a closed enum (reduced attack surface vs. arbitrary strings).

## Self-Check: PASSED

- `grep "enum Action" components/mountable-body.gd` — 1 result at line 4 (PASS)
- `grep "FIRE," components/mountable-body.gd` — 1 result (PASS)
- `grep "USE_RATE" components/mountable-body.gd` — 1 result (PASS)
- `grep "action: Action" components/mountable-body.gd` — 1 result at line 40 (PASS)
- `grep 'action == "recoil"' components/mountable-body.gd` — 0 results (PASS)
- `grep "action == Action.RECOIL" components/mountable-body.gd` — 1 result at line 44 (PASS)
- `grep "for mount in mounts:" components/mountable-body.gd` — 1 result (plan 01 fix preserved, PASS)
- `grep 'action: MountableBody.Action' components/mountable-weapon.gd` — 1 result (PASS)
- `grep 'Action.RECOIL' components/mountable-weapon.gd` — 1 result (PASS)
- `grep '"fire"' components/mountable-weapon.gd` — 0 results (PASS)
- `grep 'action: MountableBody.Action' components/mount-point.gd` — 1 result (PASS)
- `grep 'action: MountableBody.Action' world.gd` — 1 result (PASS)
- `grep 'MountableBody.Action.FIRE' world.gd` — 4 results (PASS)
- `grep 'notify_weapons("' world.gd` — 0 results (PASS)
- `grep '"fire"' world.gd` — 0 results (PASS)
- Task 1 commit 7d50eae — present in git log (PASS)
- Task 2 commit 4fc58e9 — present in git log (PASS)
