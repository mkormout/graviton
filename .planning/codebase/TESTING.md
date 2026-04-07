# Testing Patterns

**Analysis Date:** 2026-04-07

## Automated Tests

**None exist.** There are no test files, no test directories, and no test framework installed or configured in this project.

- No `test/` or `tests/` directory
- No GUT (Godot Unit Test) addon or any other testing addon in the project
- No `addons/` directory present
- No test-related entries in `project.godot`
- No `.gd` files with `test_` or `_test` naming

## Test Framework

**Not applicable.** No framework is present or configured.

GUT (the standard Godot testing framework) is not installed. There is no equivalent alternative.

## Debug and Development Utilities

Several lightweight debug mechanisms exist in the codebase as substitutes for formal testing:

**In-scene debug panels:**
- `prefabs/ui/weapon-debug-panel.tscn` + `components/weapon-debug-panel.gd` — renders live weapon state (magazine, cooldown timer, velocity, reload timer, ammo, health) to screen during play
- `prefabs/ui/hud.gd` (`HudDebugPanel`) — displays ship health and coin count live during play
- Both panels are driven by `_process()` polling, showing real-time internal state

**Commented-out print statements (left as markers):**
- `components/body.gd` line 26: `# print("damage: ", total, "; health: ", health)` — tracks damage events
- `components/explosion.gd` line 89: `# print("kickback: ", impulse)` — tracks explosion impulse
- These represent past debug sessions; the comments remain as breadcrumbs

**Active print statement:**
- `components/inventory-slot.gd` line 71: `print("_get_drag_data: ", data)` — logs drag-and-drop data to console every time a drag starts (this appears to be an oversight left from development)

**Runtime god-mode flags for gameplay testing:**
- `world.gd` uses keyboard shortcuts to trigger in-game states useful for testing weapon behavior:
  - `G` → enables `godmode` on all weapons (infinite ammo + no rate limit)
  - `H` → disables ammo consumption
  - `J` → disables rate limiting
  - `R` → reloads weapons
  - `1–6` → swaps all weapon slots to a specific weapon type
  - `ENTER` → spawns 10 more asteroids
- These are hardcoded in `_input()` in `world.gd` and are always active; there is no build flag to strip them

**`@tool` annotation:**
- `prefabs/ui/inventory/inventory-slot.gd` uses `@tool`, making the inventory slot visible and functional in the Godot editor — used to preview slot appearance by type without running the game

## Manual Testing Approach

Testing is entirely manual and play-based. The approach apparent from code:

1. Run the game from `world.tscn` (the main scene)
2. Use keyboard shortcuts (`G`, `H`, `J`, `1–6`) to configure weapon state
3. Observe on-screen debug panels for weapon and ship stats
4. Trigger scenarios (spawn asteroids with `ENTER`, switch cameras with `C`, swap weapons with number keys)
5. Check console output for any active `print()` calls

There is no regression safety net — changes to `Body`, `MountableWeapon`, or `Inventory` logic cannot be verified automatically.

## Coverage

**None.** No coverage tooling, no coverage targets, no enforcement.

---

*Testing analysis: 2026-04-07*
