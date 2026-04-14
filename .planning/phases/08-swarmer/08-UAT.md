---
status: complete
phase: 08-swarmer
source: [08-01-SUMMARY.md, 08-02-SUMMARY.md]
started: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Swarmer Wave Spawns
expected: After clearing wave 1, wave 2 triggers automatically and 5 Swarmers appear in the world. They start passive (not immediately charging the player).
result: pass

### 2. Swarmer Seek Behavior
expected: When the player flies within detection range, idle Swarmers switch to SEEKING and steer toward the player. Each Swarmer approaches on a slightly different angle (spread cluster, not all on the exact same vector) due to the per-instance angle offset.
result: pass

### 3. Swarmer Cohesion
expected: While seeking, Swarmers within ~900 units of each other pull toward the group center. The cluster should move loosely together — swarmers that stray from the group get pulled back in rather than wandering off solo.
result: pass

### 4. Swarmer Separation
expected: Swarmers that get too close to each other push apart — they should not overlap or stack. The cluster should look like a loose formation, not a single piled-up blob.
result: pass

### 5. Swarmer Fight and Fire
expected: When a Swarmer closes to fight range (~600 units), it switches to FIGHTING: it fires weak bullets at the player and maintains distance. Switching back to SEEKING if the player moves beyond fight_range × 1.2.
result: pass

### 6. Swarmer Death
expected: Killing a Swarmer plays the explosion, possibly drops a coin or ammo, and reduces the wave enemy count. The remaining Swarmers continue seeking/fighting normally.
result: pass

### 7. Wave HUD Display
expected: A panel at the top-center of the screen shows "WAVE N" and the remaining / total enemy count. It is hidden before the first wave starts, updates as enemies die, and shows "ALL CLEAR" after all waves are complete.
result: pass

### 8. Enemy Radar Arrows
expected: When enemies are off-screen, red triangular arrows appear on the screen border pointing toward them. Arrows update each frame as enemies move. Arrows disappear when enemies come on-screen or die.
result: pass

### 9. Enemy Radar — Camera Switch
expected: Pressing KEY_C to toggle between ship-follow and overview cameras does not break the radar arrows — they still point correctly after switching cameras.
result: pass

## Summary

total: 9
passed: 9
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
