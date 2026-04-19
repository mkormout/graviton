---
phase: 18-weapons-improvements
plan: 10
subsystem: ui
tags: [godot, gdscript, hud, canvaslayer, weapon-feedback, screen-shake]

# Dependency graph
requires:
  - phase: 18-weapons-improvements
    provides: fired_heavy signal on GausscannonWeapon, RpgWeapon, GravityGun (plans 18-01 through 18-09)
  - phase: 18-weapons-improvements
    provides: BodyCamera.shake() method (plan 18-01)
  - phase: 18-weapons-improvements
    provides: RpgWeapon.lock_target / lock_progress properties (plan 18-05)
  - phase: 18-weapons-improvements
    provides: MinigunWeapon.get_spool() (plan 18-03), GausscannonWeapon.get_charge_fraction(), GravityGun.get_charge_fraction()
provides:
  - WeaponHud CanvasLayer: ammo counter, reload bar, charge/spool bar, RPG lock bracket
  - world.gd: weapon_hud instantiation, connect_to_ship wiring, _wire_heavy_weapon_shake helper
affects: [any future plans touching world.gd HUD instantiation or weapon feedback]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CanvasLayer + connect_to_ship() pattern: same as WaveHud and ScoreHud"
    - "Duck-type has_method() for weapon-type detection without hard coupling"
    - "is_instance_valid() guard on weapon ref each frame to avoid stale references"
    - "is_connected() duplicate-connection guard before connecting signals on restart"

key-files:
  created:
    - prefabs/ui/weapon-hud.gd
    - prefabs/ui/weapon-hud.tscn
  modified:
    - world.gd

key-decisions:
  - "Duck-type has_method() for charge/spool detection avoids importing weapon subclass types into HUD"
  - "has_method('_scan_cone') used as RPG type guard before casting to RpgWeapon for lock bracket"
  - "fired_heavy wired in _wire_heavy_weapon_shake() helper called from both _ready() and _restart_game() for clean restart reconnection"
  - "is_connected() guard prevents duplicate signal connections on repeated restarts (T-18-10-02)"

patterns-established:
  - "WeaponHud._process(): poll body_opposite each frame; hide panel when weapon invalid"
  - "Lock bracket world-to-screen: get_viewport().get_canvas_transform() * world_pos"

requirements-completed: [WPN-11]

# Metrics
duration: 20min
completed: 2026-04-19
---

# Phase 18 Plan 10: Weapon HUD Summary

**WeaponHud CanvasLayer with per-frame ammo/reload/charge/lock display wired into world.gd with fired_heavy screen-shake connections**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-19T00:00:00Z
- **Completed:** 2026-04-19T00:20:00Z
- **Tasks:** 2 of 2 implementation tasks complete (checkpoint pending)
- **Files modified:** 3

## Accomplishments

- Created WeaponHud CanvasLayer (weapon-hud.gd + weapon-hud.tscn) with ammo counter, reload progress bar, charge/spool bar, and RPG lock bracket
- Wired WeaponHud into world.gd: preload, instantiate, connect_to_ship in _ready() and _restart_game()
- Added _wire_heavy_weapon_shake() helper that connects fired_heavy signals from mounted heavy weapons to ShipCamera.shake(), with duplicate-connection guard

## Task Commits

1. **Task 1: Create weapon-hud.gd and weapon-hud.tscn** - `76639cd` (feat)
2. **Task 2: Wire WeaponHud and fired_heavy signals into world.gd** - `c0ec3bc` (feat)

## Files Created/Modified

- `prefabs/ui/weapon-hud.gd` - WeaponHud class: connect_to_ship(), per-frame weapon polling, reload/charge/lock display
- `prefabs/ui/weapon-hud.tscn` - CanvasLayer scene: Panel bottom-center with VBox (WeaponName, AmmoLabel, ReloadBar, ChargeBar) and LockBracket Control
- `world.gd` - weapon_hud preload + instantiation, connect_to_ship in _ready() and _restart_game(), _wire_heavy_weapon_shake() helper

## Decisions Made

- Duck-type `has_method()` for charge/spool detection avoids coupling HUD to weapon subclass types
- `has_method("_scan_cone")` used as RPG type guard before casting to RpgWeapon for lock bracket (T-18-10-04)
- `_wire_heavy_weapon_shake()` is a standalone helper for easy reuse in _restart_game()
- `is_connected()` guard prevents duplicate signal connections on repeated restarts (T-18-10-02)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

All Phase 18 implementation complete. Human-verify checkpoint pending to confirm all 10 visual/behavioral items work correctly in the Godot editor.

---
*Phase: 18-weapons-improvements*
*Completed: 2026-04-19*
