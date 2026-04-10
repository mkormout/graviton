# Graviton

## What This Is

A 2D space shooter built in Godot 4, featuring a component-based ship architecture with hot-swappable weapon mounts, an inventory system, and procedurally scattered asteroids. The player pilots a ship, equips weapons from inventory, and destroys asteroids and (eventually) enemy ships.

## Core Value

The mount-and-weapon system must work reliably — ships can equip, fire, and swap weapons without bugs or silent failures.

## Requirements

### Validated

- ✓ Player ship is controllable and movable — existing
- ✓ Weapons can be mounted/unmounted at runtime — existing
- ✓ Multiple weapon types (minigun, laser, gausscannon, RPG, gravitygun) — existing
- ✓ Inventory system with drag-and-drop UI — existing
- ✓ Asteroids spawn and collide with ships — existing
- ✓ Item drops (coins, ammo, weapons, health) — existing
- ✓ Ammo tracking and reload system — existing

### Active

- [ ] Collision damage fires correctly with accurate contact position
- [ ] Reload signal does not stack duplicate connections
- [ ] Spawn parents use stable node references instead of `get_tree().current_scene`
- [ ] Action dispatch uses typed constants instead of raw strings
- [ ] Mount lookup does not call `find_children()` every physics frame
- [ ] Debug `print()` statements removed from hot paths
- [ ] Game runs correctly on Godot 4.6.2

### Out of Scope

- Enemy ship AI — deferred to Milestone 3 (approach not yet decided)
- Multiplayer — not planned
- Procedural level generation — not planned

## Context

Godot 4.4 project. The codebase uses a scene-tree component pattern: ships are `MountableBody` nodes with named `MountPoint` children; behavior comes from GDScript components rather than inheritance. `PlayerShip` and `EnemyShip` are intentionally thin subclasses — movement is handled by the `propeller-movement` component in the scene.

`world.gd` is currently a developer test harness with all input hardcoded (keys Q/W/E/1-6/etc.). This is the main scene and serves as the game entry point for now.

Known bugs identified via codebase map (April 2026):
- `ship.gd:38` — `RayCast2D` never added to scene tree; collision damage fires unconditionally
- `mountable-weapon.gd:69` — reload signal stacks a new connection on every `reload()` call
- `get_tree().current_scene` used as spawn parent — fragile reference

## Constraints

- **Engine**: Godot 4 (GDScript) — no C# or other language targets
- **Migration target**: Godot 4.6.2 in Milestone 2
- **Scope**: Bug fixes and stabilization before migration; no new gameplay features in M1

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Enemy AI deferred to Milestone 3 | Approach not yet decided; not blocking stabilization | — Pending |
| Milestone order: fix → migrate → AI | Migration is easier on clean code; bugs should be fixed before upgrading | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-07 after initialization*
