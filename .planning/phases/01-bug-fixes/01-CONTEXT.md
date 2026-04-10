# Phase 1: Bug Fixes - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate 3 known runtime defects in the Godot 4 space shooter:
1. Collision damage: `RayCast2D` created but never added to scene tree
2. Reload signal: duplicate connections stack on every `reload()` call
3. Spawn parent: `get_tree().current_scene` used as parent for bullets, explosions, item drops

This phase does NOT include code quality improvements (string dispatch, find_children, print — those are Phase 2).

</domain>

<decisions>
## Implementation Decisions

### Collision Damage (BUG-01)
- **D-01:** Fix the RayCast2D — add it to the scene tree and use it properly (do NOT remove it or simplify to blind contact damage)
- **D-02:** Damage scales with **impact speed** (using the colliding body's `linear_velocity` magnitude) — faster collision = more damage
- **D-03:** The existing `Damage` resource with `kinetic` field should be reused; the fixed 1000 value becomes a speed-scaled amount

### Reload Signal (BUG-02)
- **D-04:** Fix using `CONNECT_ONE_SHOT` flag — signal disconnects itself after firing once; idiomatic Godot 4 approach

### Spawn Parent (BUG-03)
- **D-05:** Replace `get_tree().current_scene` with an **`@export` NodePath** on each spawning component
- **D-06:** Each component that spawns nodes (bullets, explosions, item drops) gets its own `@export var spawn_parent: Node` — set in the scene editor
- **D-07:** The `world.tscn` scene should wire these references in the editor (not in code)

### Claude's Discretion
- The exact speed-to-damage formula (linear scaling, clamped, squared, etc.) — pick what feels reasonable for a space shooter
- Which node adds the RayCast2D to the tree (ship itself or a deferred call) — use whatever is most robust in Godot 4

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source Files
- `components/ship.gd` — contains the broken `body_entered` with RayCast2D and Damage logic
- `components/mountable-weapon.gd` — contains the reload signal stacking bug (line ~69)
- `components/damage.gd` — Damage resource definition (kinetic field)
- `components/bullet.gd` — spawns into scene using current_scene pattern
- `components/explosion.gd` — spawns into scene using current_scene pattern
- `components/item-drop.gd` — spawns into scene using current_scene pattern
- `components/item-dropper.gd` — spawns into scene using current_scene pattern

### Scene Files
- `world.tscn` — main scene where @export spawn_parent references will be wired
- `prefabs/ship-bfg-23/ship-bfg-23.tscn` — player ship scene with mount points

### Planning
- `.planning/codebase/CONCERNS.md` — original concern analysis
- `.planning/REQUIREMENTS.md` — BUG-01, BUG-02, BUG-03 definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Damage` resource (`components/damage.gd`) — already has `kinetic` field; reuse for scaled collision damage
- `MountableBody` base class — ships inherit from this; collision handling lives in `Ship` which extends it
- Existing `@export` pattern already used throughout the codebase (e.g., `@export var storage: Inventory` in ship.gd)

### Established Patterns
- `@export` for scene-wired references is the established Godot pattern in this codebase
- `connect()` used throughout; CONNECT_ONE_SHOT is a Godot 4 built-in flag on the same API
- `RigidBody2D.linear_velocity` available on asteroids and ships for speed-based damage

### Integration Points
- `ship.gd:_ready()` — where collision signal connects; RayCast2D fix goes here
- `mountable-weapon.gd:reload()` — where signal stacks; CONNECT_ONE_SHOT fix goes here
- All files using `get_tree().current_scene` as spawn parent — ~7 files, primarily in components/

</code_context>

<specifics>
## Specific Ideas

- Impact speed damage: `body.linear_velocity.length()` gives speed in px/s — scale kinetic damage proportionally (e.g., `speed / 10.0` gives 100 damage at 1000px/s)
- RayCast2D fix: must call `add_child(ray)` and `ray.force_raycast_update()` before querying collision point, or use `PhysicsDirectSpaceState2D` query instead

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-bug-fixes*
*Context gathered: 2026-04-07*
