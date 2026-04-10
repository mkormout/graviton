---
phase: 03-godot-4-6-2-migration
plan: 01
subsystem: infra
tags: [godot, gdscript, signal, export-preset, migration]

requires:
  - phase: 02-code-quality
    provides: cleaned codebase with typed actions, stable spawn_parent, no debug prints

provides:
  - Modern signal-object connect() syntax in ship.gd, bullet.gd, mountable-weapon.gd
  - Linux export preset with Godot 4.3+ compatible platform identifier

affects:
  - 03-02-PLAN (opens project in Godot 4.6.2 editor — these fixes prevent deprecation warnings on first open)

tech-stack:
  added: []
  patterns:
    - "Signal-object syntax: signal_name.connect(callable) instead of connect(\"signal_name\", callable)"
    - "CONNECT_ONE_SHOT flag passed directly in signal-object syntax: signal.connect(fn, CONNECT_ONE_SHOT)"

key-files:
  created: []
  modified:
    - components/ship.gd
    - components/bullet.gd
    - components/mountable-weapon.gd
    - export_presets.cfg

key-decisions:
  - "body_entered method renamed to _on_body_entered in ship.gd to avoid name conflict with RigidBody2D signal of same name"
  - "CONNECT_ONE_SHOT preserved in mountable-weapon.gd timeout.connect() — prevents duplicate handler stacking on repeated reload() calls"

patterns-established:
  - "Signal handlers connected via signal-object syntax: body_entered.connect(_on_body_entered)"
  - "Signal handlers for child nodes: picker.body_entered.connect(picker_body_entered)"
  - "One-shot timer connections: timer.timeout.connect(handler, CONNECT_ONE_SHOT)"

requirements-completed: [MIG-01, MIG-02]

duration: 15min
completed: 2026-04-10
---

# Phase 03 Plan 01: Pre-Migration Deprecation Fixes Summary

**Four deprecated string-based connect() calls replaced with signal-object syntax and Linux export preset updated to Godot 4.3+ platform identifier**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-10T14:05:00Z
- **Completed:** 2026-04-10T14:20:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Replaced all 4 string-based `connect("signal_name", callable)` calls with modern `signal_name.connect(callable)` syntax
- Renamed `Ship.body_entered` method to `_on_body_entered` to resolve name collision with `RigidBody2D.body_entered` signal
- Updated Linux export preset `platform` value from `"Linux/X11"` to `"Linux"` (Godot 4.3+ requirement)
- Zero string-based connect() calls remain anywhere in the codebase

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix 4 deprecated string-based connect() calls** - `2ff168c` (feat)
2. **Task 2: Fix Linux export preset platform identifier** - `42ed7aa` (chore)

**Plan metadata:** committed with SUMMARY.md

## Files Created/Modified
- `components/ship.gd` - `_ready()` uses signal-object syntax; `body_entered` method renamed to `_on_body_entered`
- `components/bullet.gd` - `_ready()` uses signal-object syntax for `body_entered`
- `components/mountable-weapon.gd` - `reload()` uses `reload_timer.timeout.connect(reloaded, CONNECT_ONE_SHOT)`
- `export_presets.cfg` - `platform="Linux"` in preset.1 (was `"Linux/X11"`)

## Decisions Made
- Renamed `body_entered` method to `_on_body_entered` — in Godot 4 with signal-object syntax, `body_entered` unqualified resolves to the signal, not the method, causing a runtime error. The `_on_` prefix follows Godot's established convention for signal handlers (already used in `_on_slot_item_adding`, `_on_slot_item_removing`).
- Kept `name="Linux/X11"` unchanged in export_presets.cfg — the `name` field is a user-visible display label only; the `platform` field is what Godot reads to identify the exporter.

## Deviations from Plan

None - plan executed exactly as written.

(Note: `mountable-weapon.gd` at HEAD already had `is_reloading()` guard and `CONNECT_ONE_SHOT` from Phase 01/02 work; the plan's `<interfaces>` block showed the pre-fix state. The edit was straightforward string-to-signal-object conversion with CONNECT_ONE_SHOT preserved.)

## Issues Encountered
- Initial `git reset --soft` (branch base correction) left the worktree's working tree pointing at an older branch state, causing unrelated file modifications and `.planning/` deletions to appear as staged changes. Resolved by restoring all affected files to HEAD before applying task changes.

## Known Stubs

None.

## Threat Flags

None — all changes are pure syntax refactors with no new network endpoints, auth paths, or schema changes.

## Next Phase Readiness
- All known deprecated API calls in the codebase are fixed
- Linux export preset is Godot 4.3+ compatible
- Ready for Plan 02: open project in Godot 4.6.2 editor and handle any conversion prompts

---
*Phase: 03-godot-4-6-2-migration*
*Completed: 2026-04-10*
