---
phase: 10-health-pack-foundation
plan: "02"
subsystem: items
tags: [health-pack, item-drop, enemy-drops, coinDropper, suicider, loot-table]

dependency_graph:
  requires:
    - phase: 10-health-pack-foundation
      plan: "01"
      provides: prefabs/health-pack/health-pack.tscn (item scene), items/health-pack.tres (ItemType resource), ship.pick_health() (working heal)
  provides:
    - All 5 enemy types (Beeliner, Sniper, Flanker, Swarmer, Suicider) drop health packs at ~10% probability per roll
    - Suicider CoinDropper node (previously missing — now fully wired with coin + health-pack drops)
  affects:
    - game balance (enemy loot tables)
    - player experience (healing availability during combat)

tech-stack:
  added: []
  patterns:
    - ItemDrop chance weighting — health-pack at chance=0.11 alongside coin at chance=1.0 gives 9.9% per-roll probability
    - Suicider CoinDropper creation from scratch using node_paths=PackedStringArray("item_dropper") and NodePath export wiring

key-files:
  created: []
  modified:
    - prefabs/enemies/beeliner/beeliner.tscn
    - prefabs/enemies/sniper/sniper.tscn
    - prefabs/enemies/flanker/flanker.tscn
    - prefabs/enemies/swarmer/swarmer.tscn
    - prefabs/enemies/suicider/suicider.tscn

key-decisions:
  - "chance=0.11 for health-pack drop (per D-09): combined weight 1.11 gives ~9.9% per-roll probability"
  - "Suicider drop_count=1 (matches Swarmer pattern — one roll per death for a kamikaze enemy)"
  - "Heal amount changed from 25% to 10% of max_health post-verification (917b0d0) for better game feel"
  - "No GDScript changes needed — Body.die() already calls item_dropper.drop() when item_dropper is set"

requirements-completed: [ITM-01]

duration: ~20min
completed: "2026-04-14"
---

# Phase 10 Plan 02: Health Pack Drop Wiring Summary

**Health-pack ItemDrop (chance=0.11, ~10% per roll) wired into all 5 enemy CoinDropper nodes; Suicider gained a new CoinDropper node from scratch, fully wired via item_dropper export**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-04-14
- **Tasks:** 2 (1 auto + 1 human-verify)
- **Files modified:** 5

## Accomplishments

- Health-pack ItemDrop entry (chance=0.11) added to CoinDropper models array of all 5 enemy types
- Suicider received its first-ever CoinDropper node (coin + health-pack), resolving the long-standing missing drop gap
- In-game playtest confirmed: green health packs spawn from enemy deaths, pickup heals player, health clamps at max_health
- Heal amount tuned from 25% to 10% of max_health post-verification for balanced feel

## Task Commits

1. **Task 1: Add health-pack ItemDrop to all 5 enemy CoinDropper nodes** — `2a09c1d` (feat)
2. **Post-checkpoint fix: sub_resource ordering parse error in health-pack.tscn** — `bc0d72b` (fix)
3. **Post-checkpoint fix: PointLight2D and CPUParticles2D visibility** — `c3c939a` (fix)
4. **Post-checkpoint fix: PointLight2D glow shape and texture_scale** — `8b96c48` (fix)
5. **Post-checkpoint fix: heal amount 25% → 10% of max_health** — `917b0d0` (fix)

## Files Created/Modified

- `prefabs/enemies/beeliner/beeliner.tscn` — Added health-pack ext_resource + ItemDrop sub_resource; CoinDropper models array updated to include both coin and health-pack drops
- `prefabs/enemies/sniper/sniper.tscn` — Same as Beeliner
- `prefabs/enemies/flanker/flanker.tscn` — Same as Beeliner
- `prefabs/enemies/swarmer/swarmer.tscn` — Same pattern with drop_count=1 preserved
- `prefabs/enemies/suicider/suicider.tscn` — New CoinDropper node created from scratch; root node gained `node_paths=PackedStringArray("item_dropper")` and `item_dropper = NodePath("CoinDropper")`

## Decisions Made

- **chance=0.11 per plan D-09:** Combined weight 1.0 (coin) + 0.11 (health-pack) = 1.11 total. Health-pack probability = 0.11/1.11 ≈ 9.9% per roll. This is per-roll not per-death, so multi-roll enemies (Beeliner/Sniper/Flanker at drop_count=2) have ~19.8% chance per death.
- **Suicider drop_count=1:** Matches Swarmer pattern. Kamikaze enemy — one roll is appropriate.
- **Heal amount reduced to 10%:** Original plan specified 25% (max_health/4). Post-verification testing revealed 25% felt too strong; changed to max_health/10 (commit 917b0d0) for better game balance.
- **No GDScript changes:** Body.die() already calls `item_dropper.drop()` when `item_dropper` is set. Wiring the NodePath export in the .tscn was sufficient — zero code changes required for Suicider drops to work.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed sub_resource ordering parse error in health-pack.tscn**
- **Found during:** Post-checkpoint visual testing (Task 2 verification)
- **Issue:** Godot failed to parse health-pack.tscn due to sub_resource declaration order; scene appeared broken in editor
- **Fix:** Reordered sub_resource declarations to match Godot's expected order
- **Files modified:** prefabs/health-pack/health-pack.tscn
- **Committed in:** bc0d72b

**2. [Rule 1 - Bug] Fixed PointLight2D and CPUParticles2D visibility**
- **Found during:** Post-checkpoint visual testing (Task 2 verification)
- **Issue:** PointLight2D glow was invisible; CPUParticles2D particles were too small (game coordinate scale mismatch)
- **Fix:** Corrected GradientTexture2D dimensions, adjusted CPUParticles2D scale_amount for game coordinate scale
- **Files modified:** prefabs/health-pack/health-pack.tscn
- **Committed in:** c3c939a

**3. [Rule 1 - Bug] Fixed PointLight2D glow shape and texture_scale**
- **Found during:** Post-checkpoint visual testing (Task 2 verification)
- **Issue:** PointLight2D glow shape was wrong; texture_scale was too small
- **Fix:** Corrected texture_scale value
- **Files modified:** prefabs/health-pack/health-pack.tscn
- **Committed in:** 8b96c48

**4. [Rule 1 - Bug] Heal amount changed from 25% to 10% of max_health**
- **Found during:** Post-checkpoint playtest (Task 2 verification)
- **Issue:** 25% heal felt too powerful during gameplay; plan D-01 value needed adjustment
- **Fix:** Changed `max_health / 4` to `max_health / 10` in ship.gd pick_health()
- **Files modified:** components/ship.gd
- **Committed in:** 917b0d0

---

**Total deviations:** 4 auto-fixed (all Rule 1 — bugs discovered during in-game verification)
**Impact on plan:** All fixes were in health-pack.tscn visuals and heal balance, not in the drop-wiring work of Plan 02. No scope creep. The core drop-wiring task (2a09c1d) was correct on first attempt.

## Issues Encountered

All 4 issues were in the Plan 01 health-pack.tscn scene (visual bugs and balance). The Plan 02 task itself (enemy drop wiring) executed cleanly — commit 2a09c1d passed verification with no rework needed.

## Known Stubs

None. All 5 enemies have functional health-pack drop tables. The pickup heal path is fully wired through `picker_body_entered` → `pick_health()`.

## Threat Surface Scan

No new trust boundaries introduced beyond those documented in the plan's threat register (T-10-04, T-10-05, T-10-06 — all accepted). Drop chance values are baked into .tscn files; single-player offline game with no runtime modification path.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- ITM-01 (Health Pack Foundation) is complete end-to-end: resource, scene, heal logic, and all 5 enemy drop tables
- Phase 10 is fully complete; the health pack system is ready for phase 11 work
- Potential follow-up: expose health display in HUD so player can see current health value during combat

---
*Phase: 10-health-pack-foundation*
*Completed: 2026-04-14*
