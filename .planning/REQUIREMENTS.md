# Requirements: Graviton

**Defined:** 2026-04-07
**Core Value:** The mount-and-weapon system must work reliably — ships can equip, fire, and swap weapons without bugs or silent failures.

## v1 Requirements (Milestone 1 — Stabilize)

### Bug Fixes

- [ ] **BUG-01**: Collision damage fires with correct logic — RayCast2D is added to scene tree before querying contact point
- [ ] **BUG-02**: Reload signal does not accumulate duplicate connections across multiple reload() calls
- [ ] **BUG-03**: Spawned nodes use a stable parent reference instead of `get_tree().current_scene`

### Code Quality

- [ ] **QUA-01**: Action dispatch uses typed constants instead of raw string literals ("fire", "reload", etc.)
- [ ] **QUA-02**: Mount point lookup is cached or event-driven — `find_children()` not called every physics frame
- [ ] **QUA-03**: Debug `print()` statements removed from production hot paths (inventory drag-and-drop)

## v1 Requirements (Milestone 2 — Godot 4.6.2 Migration)

### Migration

- [ ] **MIG-01**: Project opens and runs without errors in Godot 4.6.2
- [ ] **MIG-02**: All deprecated API calls identified and updated to 4.6.2 equivalents
- [ ] **MIG-03**: Export presets verified and functional after migration

## v2 Requirements (Milestone 3 — Enemy AI)

### Enemy Behavior

- **ENM-01**: EnemyShip moves toward or patrols around a target
- **ENM-02**: EnemyShip fires weapons when player is in range
- **ENM-03**: EnemyShip can be destroyed and drops items
- **ENM-04**: Enemy ships spawn in the world scene

## Out of Scope

| Feature | Reason |
|---------|--------|
| Enemy ship AI | Deferred to Milestone 3 — approach not yet decided |
| Multiplayer | Not planned |
| Procedural level generation | Not planned |
| Automated test suite (GUT) | User opted for manual playtesting |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-01 | Phase 1 | Pending |
| BUG-02 | Phase 1 | Pending |
| BUG-03 | Phase 1 | Pending |
| QUA-01 | Phase 2 | Pending |
| QUA-02 | Phase 2 | Pending |
| QUA-03 | Phase 2 | Pending |
| MIG-01 | Phase 3 | Pending |
| MIG-02 | Phase 3 | Pending |
| MIG-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements (M1+M2): 9 total
- Mapped to phases: 9
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-07*
*Last updated: 2026-04-07 after initial definition*
