---
phase: 01-bug-fixes
plan: 01
subsystem: gameplay
tags: [gdscript, godot4, physics, raycast, signals, collision, reload]

requires: []
provides:
  - Fixed RayCast2D collision handler in ship.gd — ray added to scene tree, speed-scaled kinetic damage
  - Fixed reload signal stacking in mountable-weapon.gd — CONNECT_ONE_SHOT + is_reloading() guard
affects:
  - 01-02
  - 01-03

tech-stack:
  added: []
  patterns:
    - "One-shot RayCast2D query: create node, add_child(), force_raycast_update(), read, queue_free()"
    - "One-shot signal connection: connect(signal, handler, CONNECT_ONE_SHOT)"
    - "Reload guard: check is_reloading() before starting a new reload cycle"

key-files:
  created: []
  modified:
    - components/ship.gd
    - components/mountable-weapon.gd

key-decisions:
  - "speed / 10.0 as kinetic damage formula — gives 100 damage at 1000 px/s as playtesting baseline"
  - "contact_point variable retained in ship.gd for future Phase 2 hit effects (currently unused)"

patterns-established:
  - "RayCast2D one-shot pattern: add_child before force_raycast_update, queue_free after read"
  - "Signal one-shot: CONNECT_ONE_SHOT flag rather than manual disconnect"

requirements-completed:
  - BUG-01
  - BUG-02

duration: 10min
completed: 2026-04-07
---

# Phase 01 Plan 01: BUG-01 and BUG-02 Fix Summary

**RayCast2D collision damage grounded in physics with speed-scaled kinetic, and reload signal de-duplicated with CONNECT_ONE_SHOT and is_reloading() guard**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-07T20:08:00Z
- **Completed:** 2026-04-07T20:18:19Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Fixed `ship.gd:body_entered` — RayCast2D now added to scene tree before querying, target uses `to_local()` for correct local-space direction, damage is `speed / 10.0` instead of hardcoded 1000
- Fixed `mountable-weapon.gd:reload` — `CONNECT_ONE_SHOT` prevents signal accumulation, `is_reloading()` guard stops mid-reload re-entry
- Retained `contact_point` variable in ship.gd for upcoming Phase 2 hit effects without behavioral change

## Task Commits

1. **Task 1: Fix BUG-01 — RayCast2D collision handler in ship.gd** - `218ea9c` (fix)
2. **Task 2: Fix BUG-02 — Reload signal stacking in mountable-weapon.gd** - `a3afd75` (fix)

## Files Created/Modified

- `components/ship.gd` - Fixed `body_entered`: RayCast2D properly added to tree, local-space target, speed-scaled damage, contact_point captured, ray cleaned up
- `components/mountable-weapon.gd` - Fixed `reload()`: is_reloading() guard + CONNECT_ONE_SHOT flag

## Decisions Made

- `speed / 10.0` chosen as the kinetic damage formula — this gives 100 kinetic at 1000 px/s as a playtesting baseline per plan's "Claude's Discretion" note; not a final tuned value
- `contact_point` variable kept unused in ship.gd so Phase 2 hit effects can reference it without changing the function signature

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BUG-01 and BUG-02 are resolved; 01-02 and 01-03 can proceed independently
- No blockers or concerns

---
*Phase: 01-bug-fixes*
*Completed: 2026-04-07*
