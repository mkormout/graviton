---
phase: 09-suicider
plan: "02"
subsystem: enemy-ai
tags: [enemy, suicider, explosion, ai, scene, wave-spawning, visual]

dependency_graph:
  requires:
    - phase: 09-01
      provides: components/suicider.gd, prefabs/enemies/suicider/suicider-explosion.tscn, explosion.gd hit_ships patch
  provides:
    - prefabs/enemies/suicider/suicider.tscn (Suicider enemy scene)
    - world.gd WaveManager wave including Suicider
    - Colored Polygon2D shapes for all 5 enemy types (Beeliner, Flanker, Sniper, Swarmer, Suicider)
    - Tuned Suicider stats: max_speed=4000, thrust=2000, explosion radius=675, energy=17500, kinetic=5000
  affects:
    - future playtesting/balancing phases
    - any phase touching enemy visuals

tech-stack:
  added: []
  patterns:
    - Flat scene pattern for concrete enemy types (no inheritance from base scene)
    - ContactArea2D on dedicated child node for contact-triggered die()
    - Polygon2D colored shapes as enemy visual identity (distinct shape per enemy type)
    - iterative playtest tuning loop: build → playtest → tune stats → commit

key-files:
  created:
    - prefabs/enemies/suicider/suicider.tscn
  modified:
    - world.gd
    - components/suicider.gd
    - prefabs/enemies/suicider/suicider-explosion.tscn
    - prefabs/enemies/beeliner/beeliner.tscn
    - prefabs/enemies/flanker/flanker.tscn
    - prefabs/enemies/sniper/sniper.tscn
    - prefabs/enemies/swarmer/swarmer.tscn
    - components/enemy-ship.gd

key-decisions:
  - "max_speed tuned up from 2800 to 4000 — Suicider felt too slow in playtest, dangerous closing speed is the core threat"
  - "FAR_THRESHOLD brake added to suicider.gd — without it, missed Suiciders drifted offscreen indefinitely"
  - "Explosion radius settled at 675 (not 1350) — 3x felt too punishing, half that creates fair skill expression"
  - "Explosion damage escalated 10x to energy=17500, kinetic=5000 — necessary for contact to feel lethal at high player HP"
  - "Polygon2D shapes added to all enemies during playtest — could not distinguish enemy types visually at a glance"
  - "enemy-ship.gd debug draw circle infill removed — Polygon2D shapes made it visually noisy and confusing"

patterns-established:
  - "Colored Polygon2D as enemy visual identity: distinct shape+color per type (Beeliner=hexagon/yellow, Flanker=pentagon/blue, Sniper=square/magenta, Swarmer=triangle/orange, Suicider=circle/red)"
  - "Playtest tuning commits as part of checkpoint human-verify — iterative stat changes committed atomically"

requirements-completed: [ENM-11]

duration: ~30min
completed: 2026-04-13
---

# Phase 9 Plan 2: Suicider Scene + Playtest Summary

**Suicider enemy scene wired into game with ContactArea2D detonation, iterated through 9 playtest-tuning commits to reach lethal feel: max_speed=4000, explosion energy=17500/kinetic=5000/radius=675, plus Polygon2D visual identity for all 5 enemy types.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-04-13
- **Completed:** 2026-04-13
- **Tasks:** 2 (1 implementation, 1 playtest checkpoint)
- **Files modified:** 9

## Accomplishments

- Created `prefabs/enemies/suicider/suicider.tscn` — flat scene following established enemy pattern, with ContactArea2D, no Barrel/FireTimer/droppers, death=suicider-explosion.tscn
- Wired Suicider into `world.gd` WaveManager as the first wave (3 Suiciders) for playtesting
- All 6 playtest tests passed: locked-vector charge, re-acquisition on miss, contact detonation with damage+knockback, shot-to-death explosion, no double-trigger, no loot
- Added colored Polygon2D shapes to all 5 enemy types during playtest — Beeliner hexagon (yellow), Flanker pentagon (blue), Sniper square (magenta), Swarmer triangle (orange), Suicider circle (red)
- Iterated Suicider stats and explosion values across 8 tuning commits until the enemy felt dangerous and the explosion felt lethal

## Task Commits

1. **Task 1: Create suicider.tscn scene + wire world.gd** - `7ef6b26` (feat)
2. **Playtest fix: brake on far miss + 3x explosion size** - `67075f4` (fix)
3. **Playtest fix: tune Suicider speed/rotation/explosion visuals** - `1f0ffdd` (fix)
4. **Playtest fix: halve explosion radius** - `eeea162` (fix)
5. **Playtest fix: 5x explosion damage** - `bf69c8f` (fix)
6. **Playtest fix: 10x explosion damage** - `d2fee30` (fix)
7. **Playtest feat: colored polygon shapes for all enemies** - `5082bca` (feat)
8. **Playtest fix: Suicider shape outline-only** - `e653936` (fix — reverted)
9. **Playtest fix: all enemy shapes outline-only** - `a9237ad` (fix — reverted)
10. **Playtest fix: remove red circle infill, restore shape fills** - `94ea743` (fix)

## Files Created/Modified

- `prefabs/enemies/suicider/suicider.tscn` - Suicider enemy scene (created)
- `world.gd` - Added suicider_model preload and Suicider wave to WaveManager
- `components/suicider.gd` - Added FAR_THRESHOLD brake logic, tuned rotation lerp to 12.0
- `prefabs/enemies/suicider/suicider-explosion.tscn` - Final tuned values: radius=675, power=15000, energy=17500, kinetic=5000, particles=1000
- `prefabs/enemies/beeliner/beeliner.tscn` - Added yellow hexagon Polygon2D
- `prefabs/enemies/flanker/flanker.tscn` - Added blue pentagon Polygon2D
- `prefabs/enemies/sniper/sniper.tscn` - Added magenta square Polygon2D
- `prefabs/enemies/swarmer/swarmer.tscn` - Added orange triangle Polygon2D
- `components/enemy-ship.gd` - Removed filled circle from debug draw, retained dimmed arc outline

## Decisions Made

- **max_speed raised from 2800 to 4000** during playtest — Suicider felt too slow; the core threat is fast closing speed, so 4000 with ±20% random variance makes it feel threatening
- **FAR_THRESHOLD=4000 brake added** — without active braking on far miss, Suicider drifted offscreen forever; now it brakes and re-locks on current player position
- **Explosion radius settled at 675** — 450 was too small (barely punished near-contact), 1350 was too large (unavoidable), 675 rewards dodging without forgiving near-misses
- **Explosion damage escalated 10x** — energy=350 felt ticklish at player HP levels; energy=17500/kinetic=5000 makes contact potentially one-shot, which matches the "devastating" design intent
- **Polygon2D shapes added to all enemies** — empty Sprite2D nodes made all enemies look identical; distinct shapes make the game readable at a glance during playtest
- **Debug circle infill removed from enemy-ship.gd** — Polygon2D shape fills made the red debug circle redundant and visually cluttered

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Suicider drifted offscreen on far miss**
- **Found during:** Task 2 (playtest)
- **Issue:** Overshoot detection re-acquired target position but applied no braking; Suicider retained full momentum and left the playfield
- **Fix:** Added FAR_THRESHOLD=4000 constant and brake force `apply_central_force(-linear_velocity.normalized() * thrust * 2.0)` when overshoot distance exceeds threshold
- **Files modified:** `components/suicider.gd`
- **Committed in:** `67075f4`

**2. [Rule 1 - Bug] Explosion values required multiple iterations to reach intended "devastating" feel**
- **Found during:** Task 2 (playtest)
- **Issue:** Initial radius=450/power=10000/energy=350 felt weak — Suicider contact damage was not perceptibly different from a minigun hit
- **Fix:** Three tuning passes: 3x size → halve size → 5x damage → 10x damage; final state is radius=675/power=15000/energy=17500/kinetic=5000
- **Files modified:** `prefabs/enemies/suicider/suicider-explosion.tscn`
- **Committed in:** `67075f4`, `eeea162`, `bf69c8f`, `d2fee30`

**3. [Rule 2 - Missing Critical] Added visual identity (Polygon2D shapes) to all enemy types**
- **Found during:** Task 2 (playtest)
- **Issue:** All enemies were visually identical (empty Sprite2D + red debug circle) — impossible to distinguish Suicider from Beeliner from Swarmer during play
- **Fix:** Added distinct colored Polygon2D shapes to all 5 enemy scenes; removed filled debug circle from enemy-ship.gd draw_line callback
- **Files modified:** all 5 enemy .tscn files, `components/enemy-ship.gd`
- **Committed in:** `5082bca`, `94ea743`

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing critical functionality)
**Impact on plan:** All fixes necessary for the enemy to be playable and distinguishable. No scope creep — visual identity and proper braking are baseline requirements for playtesting.

## Issues Encountered

- Outline-only Polygon2D (commits `e653936`, `a9237ad`) made shapes harder to read, not easier — reverted to full fill in `94ea743`

## User Setup Required

None - no external service configuration required.

## Known Stubs

None — Suicider is fully wired: scene exists, AI script works, explosion configured, waved into WaveManager, visually distinct. No placeholder values or TODO markers.

## Threat Model Coverage

| Threat | Mitigation | Status |
|--------|------------|--------|
| T-09-05: spawn_parent missing for explosion | WaveManager._spawn_enemy() propagates spawn_parent — verified in playtest (explosion spawned correctly) | Confirmed |
| T-09-06: ContactArea detects other enemies | mask=1 + `body is PlayerShip` guard in handler — only PlayerShip triggers die() | Confirmed |
| T-09-07: wave count too high causing lag | 3 Suiciders — no performance issue observed | Confirmed |

## Next Phase Readiness

- All 5 enemy types (Beeliner, Flanker, Sniper, Swarmer, Suicider) are implemented and playable
- Phase 09 Suicider milestone is complete — enemy AI system for v2.0 milestone is fully delivered
- Visual identity per enemy type is established as a pattern for future enemy additions
- No blockers for next phase

---
*Phase: 09-suicider*
*Completed: 2026-04-13*
