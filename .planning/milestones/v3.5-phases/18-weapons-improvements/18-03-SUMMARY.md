---
phase: 18-weapons-improvements
plan: "03"
subsystem: weapons
tags: [gdscript, gausscannon, charge-mechanic, pointlight2d, cpuparticles2d, mountable-weapon]

# Dependency graph
requires:
  - phase: 18-weapons-improvements
    plan: "01"
    provides: "MountableBody.Action enum typed constants replacing raw strings"
provides:
  - "GausscannonWeapon class with hold-to-charge mechanic scaling damage/velocity/recoil"
  - "ChargeLight (PointLight2D) visual feedback glowing as charge builds"
  - "Sparks (CPUParticles2D) emitting continuously at full charge"
  - "fired_heavy signal for camera shake hook (plan 18-10)"
  - "get_charge_fraction() getter for future HUD integration"
affects:
  - "18-10 (camera shake via fired_heavy signal)"
  - "HUD plans that may display charge fraction"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Self-polling weapon pattern: _physics_process polls Input directly instead of responding to do(FIRE)"
    - "Charge-scaled shot: fraction drives lerp across velocity/recoil/damage multiplier ranges"
    - "Damage resource duplication before mutation to avoid shared-resource contamination"

key-files:
  created:
    - prefabs/gausscannon/gausscannon-weapon.gd
  modified:
    - prefabs/gausscannon/gausscannon.tscn

key-decisions:
  - "do() intentionally ignores Action.FIRE — world.gd FIRE events are no-ops; charge is self-managed via _physics_process"
  - "Damage resource duplicated via .duplicate() before scaling to never mutate shared .tres resource"
  - "PointLight2D and CPUParticles2D added directly under Barrel node to follow muzzle position"

patterns-established:
  - "Self-polling weapon: weapon reads Input.is_action_pressed() in _physics_process, bypassing do(FIRE)"
  - "Charge fraction lerp: single fraction variable drives all scaled outputs uniformly"

requirements-completed: [WPN-02]

# Metrics
duration: 5min
completed: 2026-04-19
---

# Phase 18 Plan 03: Gausscannon Hold-to-Charge Summary

**GausscannonWeapon extending MountableWeapon with hold-to-charge: 2-second charge scales damage 1x-3x, velocity 0.5x-1.0x, recoil 0.3x-1.0x; PointLight2D glows and CPUParticles2D sparks at full charge**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-19T00:00:00Z
- **Completed:** 2026-04-19T00:05:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `GausscannonWeapon` script with self-polling charge mechanic; holding KEY_SPACE charges over 2 seconds, releasing fires scaled shot
- `_fire_charged()` scales bullet velocity (0.5x–1.0x), recoil (0.3x–1.0x), and damage (1x–3x) proportionally to charge fraction; duplicates Damage resource before mutation
- Added `ChargeLight` (PointLight2D, energy 0.3→4.0) and `Sparks` (CPUParticles2D, emits at full charge) nodes under Barrel in gausscannon.tscn; scene script updated to gausscannon-weapon.gd
- `fired_heavy` signal declared for future camera shake hookup (plan 18-10); `get_charge_fraction()` exposed for HUD

## Task Commits

Each task was committed atomically:

1. **Task 1: Create gausscannon-weapon.gd with charge mechanic** - `b6df352` (feat)
2. **Task 2: Add PointLight2D and CPUParticles2D to gausscannon.tscn** - `5bc943a` (feat)

## Files Created/Modified
- `prefabs/gausscannon/gausscannon-weapon.gd` - New GausscannonWeapon class; 115 lines; extends MountableWeapon; hold-to-charge via _physics_process self-poll; do() ignores FIRE
- `prefabs/gausscannon/gausscannon.tscn` - Script changed to gausscannon-weapon.gd; ChargeLight (PointLight2D) and Sparks (CPUParticles2D) added under Barrel; export bindings set

## Decisions Made
- do() ignores Action.FIRE entirely — world.gd sends FIRE every frame KEY_SPACE is held, which would cause immediate firing; self-polling pattern gives the weapon full control of charge timing
- Damage resource is duplicated via `.duplicate()` before scaling — the shared .tres resource must never be mutated; each fired bullet gets its own resource copy (threat T-18-03-02)
- `can_shoot()` guard in `_physics_process` — charge only builds when not on cooldown or reloading, preventing cooldown bypass by holding (threat T-18-03-01)
- `if not sparks.emitting` guard prevents re-triggering emitter every frame at full charge (threat T-18-03-03)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- GausscannonWeapon is ready for integration; world.gd may need a line to connect `fired_heavy` signal to camera shake (plan 18-10 handles this)
- `get_charge_fraction()` available for HUD charge indicator (future plan)
- No blockers

---
*Phase: 18-weapons-improvements*
*Completed: 2026-04-19*
