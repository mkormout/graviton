---
phase: 18-weapons-improvements
plan: "05"
subsystem: weapons
tags: [minigun, spool, fire-rate, gdscript, godot, pointlight2d, cpuparticles2d, mountable-weapon]

# Dependency graph
requires:
  - phase: 18-weapons-improvements/18-01
    provides: recoil bug fix and MountableWeapon base class stabilization

provides:
  - MinigunWeapon class with spool-rate mechanic (base to 5x over 2s, drop in 0.5s)
  - PointLight2D glow feedback driven by spool level (0.0 to 3.0 energy)
  - CPUParticles2D spark feedback enabled at spool > 0.05
  - 1.5x damage multiplier at max spool (>= 0.95)
  - get_spool() method for Weapon HUD charge bar integration

affects:
  - 18-08 (weapon HUD — consumes get_spool() for charge bar display)
  - future minigun balance passes

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extend MountableWeapon to override fire() and _physics_process() for per-weapon mechanics"
    - "shot_timer.wait_time mutation each physics frame to vary fire rate continuously"
    - "Spool variable (0.0-1.0) driven by lerp on delta time for smooth ramp up/down"
    - "Duplicate attack resource per-bullet before add_child to avoid mutating shared .tres"
    - "PointLight2D energy and CPUParticles2D emitting tied to spool for visual feedback"

key-files:
  created:
    - prefabs/minigun/minigun-weapon.gd
  modified:
    - prefabs/minigun/minigun.tscn

key-decisions:
  - "Use shot_timer.wait_time mutation (not a separate timer) to implement continuous fire rate spool — matches existing base class architecture"
  - "Clamp _rate_max = max(rate * 0.2, 0.01) to guarantee minimum 10ms wait_time — prevents Godot timer degeneration (T-18-05-01)"
  - "Duplicate bullet attack resource before scaling — never mutate shared .tres resource (T-18-05-02)"
  - "fire() override replicates base class logic rather than calling super() to enable pre-add_child damage scaling"
  - "Input.is_action_pressed('ui_select') used for spool detection in _physics_process — matches propeller-movement.gd pattern"

patterns-established:
  - "Per-weapon subclass pattern: extend MountableWeapon, override fire() and _physics_process(), keep @export vars for scene-bound nodes"
  - "Spool/charge as float 0.0-1.0 exposed via getter for HUD consumption"

requirements-completed: [WPN-05]

# Metrics
duration: 10min
completed: 2026-04-19
---

# Phase 18 Plan 05: Minigun Spool-Rate Mechanic Summary

**MinigunWeapon class with continuous spool from base rate to 5x speed over 2 seconds, per-frame shot_timer.wait_time mutation, 1.5x damage at max spool, and PointLight2D/CPUParticles2D visual feedback**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-18T23:06:00Z
- **Completed:** 2026-04-18T23:16:13Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `prefabs/minigun/minigun-weapon.gd` — MinigunWeapon class that spools fire rate from base (0.02s wait) to 5x speed (0.004s wait) over 2 seconds of sustained fire, drops back in 0.5s on release
- Added SpoolLight (PointLight2D) and SpoolSparks (CPUParticles2D) nodes to minigun.tscn under Barrel, wired via @export NodePaths
- Override of fire() duplicates bullet attack resource before scaling by 1.5x at spool >= 0.95, never touching shared .tres

## Task Commits

Each task was committed atomically:

1. **Task 1: Create minigun-weapon.gd with spool mechanics** - `c5613ea` (feat)
2. **Task 2: Add PointLight2D and CPUParticles2D to minigun.tscn** - `5c58d76` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `prefabs/minigun/minigun-weapon.gd` - New MinigunWeapon class; spool logic, shot_timer.wait_time mutation, damage scaling, get_spool() HUD accessor
- `prefabs/minigun/minigun.tscn` - Script changed to minigun-weapon.gd; SpoolLight and SpoolSparks child nodes added under Barrel; light/sparks NodePaths bound on root

## Decisions Made
- fire() override replicates the base class fire() body (rather than calling super()) so the bullet instance is accessible before add_child, allowing damage resource duplication and scaling before the bullet enters the scene tree
- shot_timer.start(shot_timer.wait_time) in the overridden fire() uses the current spooled wait_time at the moment of firing rather than the original base rate — this is intentional and correct
- _rate_min / _rate_max cached in _ready() after super() to avoid re-reading the exported `rate` value after it may be overridden by the scene

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MinigunWeapon is ready for visual testing: equip minigun, hold SPACE, observe glow ramping over 2s
- get_spool() method ready for 18-08 Weapon HUD to consume for charge bar display
- No blockers for subsequent wave 2 plans

## Threat Surface Scan
No new network endpoints, auth paths, file access patterns, or schema changes introduced. Shot_timer.wait_time mutation clamped via _rate_max >= 0.01 (T-18-05-01). Attack resource duplication prevents shared .tres mutation (T-18-05-02).

## Self-Check: PASSED
- `prefabs/minigun/minigun-weapon.gd` — exists, verified
- `prefabs/minigun/minigun.tscn` — exists with SpoolLight, SpoolSparks, minigun-weapon.gd script reference
- Task 1 commit `c5613ea` — confirmed in git log
- Task 2 commit `5c58d76` — confirmed in git log

---
*Phase: 18-weapons-improvements*
*Completed: 2026-04-19*
