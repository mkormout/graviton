---
phase: 01-bug-fixes
plan: 03
subsystem: spawn
tags: [spawn_parent, godot, gdscript, scene-tree]

requires:
  - phase: 01-bug-fixes/01-02
    provides: "@export var spawn_parent: Node added to 6 component scripts"

provides:
  - spawn_parent wired at runtime for all dynamic spawn sites (weapons, asteroids, items, bullets, successors)
  - Explosion scenes receive spawn_parent propagated from their parent Body
  - Successor asteroid fragments propagate spawn_parent to all child nodes

affects: [any phase that spawns nodes into the world scene]

tech-stack:
  added: []
  patterns: [setup_spawn_parent() recursive helper in world.gd, _propagate_spawn_parent() in body.gd]

key-files:
  created: []
  modified:
    - world.gd
    - components/body.gd
    - components/mountable-weapon.gd
    - components/item-dropper.gd

key-decisions:
  - "spawn_parent must be set in code, not editor — everything is dynamically spawned"
  - "world.gd owns setup_spawn_parent() for nodes it creates directly"
  - "body.gd owns _propagate_spawn_parent() for nodes it spawns transitively"
  - "Removed duplicate @export var spawn_parent from MountableWeapon and Item (both inherit Body)"

patterns-established:
  - "setup_spawn_parent(node): recursive helper on World that sets spawn_parent=self on any node with the property"
  - "_propagate_spawn_parent(node): recursive helper on Body that forwards self.spawn_parent down the tree"
  - "Whenever a node is spawned dynamically, its spawn_parent must be set before add_child"

requirements-completed: [BUG-03]

duration: 45min
completed: 2026-04-07
---

# Plan 03: Wire spawn_parent exports — Summary

**spawn_parent wired entirely in code via recursive propagation helpers; all spawn sites (bullets, explosions, asteroid fragments, item drops, coin pickups) verified working**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-04-07
- **Tasks:** 2 (1 auto + 1 checkpoint)
- **Files modified:** 4

## Accomplishments
- `world.gd` sets `spawn_parent = self` on all dynamically spawned nodes via `setup_spawn_parent()` recursive helper
- Bullet instances receive `spawn_parent` from the weapon that fires them — RPG explosions now work
- Successor asteroid fragments propagate `spawn_parent` to children via `_propagate_spawn_parent()` — all fragments drop coins
- Coin pickup `pick_sound` correctly reparented to world so it survives `queue_free()`
- Removed duplicate `spawn_parent` declarations from `MountableWeapon` and `Item` (both inherit from `Body`)

## Task Commits

1. **Task 1: Propagate spawn_parent to Explosion in body.gd:die()** — `2a4604a`
2. **Fix: remove duplicate spawn_parent from Body subclasses** — `a57554b`
3. **Fix: set spawn_parent in code for all dynamic spawn sites** — `4db7930`
4. **Fix: propagate spawn_parent to bullets and successor children** — `295b671`
5. **Fix: set spawn_parent on items in ItemDropper** — `efe98d6`
6. **Task 2: Checkpoint approved by user**

## Files Created/Modified
- `world.gd` — added `setup_spawn_parent()` helper; call it on ship, weapons, and asteroids
- `components/body.gd` — added `_propagate_spawn_parent()` helper; used in `add_successor()` and `die()`
- `components/mountable-weapon.gd` — set `instance.spawn_parent` before adding bullet to scene; removed duplicate export
- `components/item-dropper.gd` — set `node.spawn_parent` before adding dropped item to scene

## Decisions Made
- Editor wiring (the plan's original approach) was not viable — the entire game world is dynamically spawned. Switched to code-side propagation.
- `MountableWeapon` and `Item` extend `Body` and therefore inherit `spawn_parent`; plan 01-02 incorrectly added duplicate declarations which caused a Godot parser error.
- Used duck-typing (`"spawn_parent" in node`) when setting spawn_parent on bullet/item instances since their types aren't statically known at the call site.

## Deviations from Plan

### Auto-fixed Issues

**1. Duplicate spawn_parent declarations on Body subclasses**
- **Found during:** User ran game, got parser error
- **Issue:** Plan 01-02 added `@export var spawn_parent` to `MountableWeapon` and `Item`, which already inherit it from `Body`
- **Fix:** Removed the duplicate declarations from both files
- **Committed in:** `a57554b`

**2. Editor wiring not viable — switched to code-side propagation**
- **Found during:** Checkpoint discussion
- **Issue:** All asteroids, weapons, bullets, and items are spawned at runtime; no static scene nodes to wire in editor
- **Fix:** Added `setup_spawn_parent()` to world.gd and `_propagate_spawn_parent()` to body.gd
- **Committed in:** `4db7930`

**3. Bullet instances missing spawn_parent (rockets not exploding)**
- **Found during:** User testing
- **Issue:** `fire()` added bullet to world via spawn_parent but never set spawn_parent on the bullet itself
- **Fix:** Set `instance.spawn_parent = spawn_parent` in `mountable-weapon.gd:fire()`
- **Committed in:** `295b671`

**4. Successor fragments not dropping coins**
- **Found during:** User testing
- **Issue:** `add_successor()` set spawn_parent on the fragment body but not on its children (ItemDropper)
- **Fix:** Replaced single assignment with `_propagate_spawn_parent()` recursive call
- **Committed in:** `295b671`

**5. Coin pickup sound not playing**
- **Found during:** User testing
- **Issue:** ItemDropper spawned items without setting spawn_parent on them; pick_sound couldn't be reparented
- **Fix:** Added `node.spawn_parent = spawn_parent` in `item-dropper.gd:drop()`
- **Committed in:** `efe98d6`

---

**Total deviations:** 5 auto-fixed
**Impact on plan:** All fixes were necessary due to the plan's incorrect assumption about editor wiring. No scope creep.

## Issues Encountered
- Plan assumed spawn_parent could be wired in the Godot editor. In reality, the entire game world is dynamically instantiated at runtime, so all wiring had to be done in code.

## Next Phase Readiness
- BUG-01, BUG-02, BUG-03 all closed
- Phase 01 complete — ready for Milestone 2 (Godot 4.6.2 migration)

---
*Phase: 01-bug-fixes*
*Completed: 2026-04-07*
