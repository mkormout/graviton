---
status: testing
phase: 06-sniper
source: [06-01-SUMMARY.md, 06-02-SUMMARY.md]
started: 2026-04-12T20:30:00.000Z
updated: 2026-04-12T20:30:00.000Z
---

## Current Test

[testing complete]

## Tests

### 1. Sniper spawns in wave 2
expected: Open game (F5). Press F once — wave 1 spawns (3 Beeliners). Press F again — wave 2 spawns exactly 2 Snipers with no console errors.
result: pass

### 2. Standoff distance — no melee charging
expected: Snipers maintain distance from the player ship. They should NOT charge in and try to ram you like Beeliners do. The debug STATE label should show SEEKING while approaching their preferred distance, then FIGHTING once at range.
result: issue
reported: "After the code review fixes, enters fighting mode less easily. After fleeing, doesn't chase again."
severity: major
fixed: "Two commits applied — c6d2457 (body_exited restricted to SEEKING), c6fab66 (removed comfort_range from SEEKING)"

### 3. Aim-up telegraph — pause before shot
expected: When a Sniper is in FIGHTING state, there should be a visible ~1 second pause between the fire timer triggering and the bullet actually launching.
result: pass

### 4. Sniper bullet feel — slow and heavy
expected: Sniper bullets slower than Beeliner bullets, more damage per hit.
result: pass
note: "Bullet speed is intentionally fast (user design choice) — damage confirmed heavier"

### 5. FLEEING state — charge and retreat
expected: Fly at sniper aggressively — enters FLEEING, moves away. Back off — returns to SEEKING.
result: pass

### 6. Loot drop on kill
expected: Killing a Sniper drops coins, possibly minigun ammo. Wave completes after both dead.
result: pass

## Summary

total: 6
passed: 5
issues: 1
pending: 0
skipped: 0

## Gaps

[none — issue in test 2 was diagnosed and fixed inline (commits c6d2457, c6fab66)]
