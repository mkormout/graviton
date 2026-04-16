---
phase: 10-health-pack-foundation
plan: "01"
subsystem: items
tags: [health-pack, item-system, pickup, healing, scene]
dependency_graph:
  requires: []
  provides:
    - items/health-pack.tres (ItemType resource, type=HEALTH)
    - prefabs/health-pack/health-pack.tscn (RigidBody2D item scene)
    - components/ship.gd pick_health() (working heal on pickup)
  affects:
    - components/ship.gd (picker_body_entered routes HEALTH to fixed pick_health)
tech_stack:
  added: []
  patterns:
    - Polygon2D emissive modulate (Color >1.0 for bloom effect without HDR)
    - PointLight2D with GradientTexture2D sub-resource for item glow
    - CPUParticles2D EMISSION_SHAPE_SPHERE for ambient aura
key_files:
  created:
    - items/health-pack.tres
    - prefabs/health-pack/health-pack.tscn
  modified:
    - components/ship.gd
decisions:
  - Direct health mutation (health = min(health + heal, max_health)) — damage() clamps to <=0 so healing cannot go through it
  - Heal amount = max_health / 4 (25%) as specified by plan D-01
  - Reused coin-pick.wav with pitch_scale=1.2 for audio differentiation without new assets
metrics:
  duration: 91s
  completed: "2026-04-14"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
---

# Phase 10 Plan 01: Health Pack Item Foundation Summary

Health-pack ItemType resource and scene created with green emissive cross visuals, PointLight2D glow, and CPUParticles2D ambient aura; Ship.pick_health() fixed to heal 25% of max_health clamped at max_health instead of incorrectly adding to storage inventory.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create health-pack item resource and scene with procedural green cross visuals | df094e5 | items/health-pack.tres, prefabs/health-pack/health-pack.tscn |
| 2 | Fix Ship.pick_health() to heal the ship instead of adding to storage | c8de67f | components/ship.gd |

## What Was Built

### items/health-pack.tres

ItemType resource for the health pack item:
- `script_class="ItemType"` with uid `uid://healthpack_res_001`
- `name = "health-pack"` — must match `prefabs/health-pack/health-pack.tscn` exactly for ItemType.init() scene loading
- `type = 3` (ItemTypes.HEALTH enum value)
- `price = 0` (no market value)
- No image or name_item fields (health packs have no UI texture or alternate scene variant)

### prefabs/health-pack/health-pack.tscn

RigidBody2D Item scene following the coin-copper.tscn pattern:
- Root: `HealthPack` RigidBody2D with `item.gd` script, `collision_layer = 32` (picker detection), `collision_mask = 0`, `linear_damp = 0.5`
- `CrossH` Polygon2D: horizontal bar (-150,-50 to 150,50), `modulate = Color(0, 2.55, 1.36, 1)` (emissive green)
- `CrossV` Polygon2D: vertical bar (-50,-150 to 50,150), same emissive green modulate
- `PointLight2D`: green color `Color(0, 1, 0.53, 1)`, energy=1.5, texture_scale=3.0, GradientTexture2D sub-resource (radial white-to-transparent)
- `CPUParticles2D`: 12 particles, omnidirectional spread=180, sphere emission radius=80, velocity 20-80, green color, scale 0.3-0.8
- `CollisionShape2D`: CircleShape2D radius=150
- `AudioStreamPlayer2D`: coin-pick.wav, volume_db=-20, pitch_scale=1.2 (differentiated from coin's 0.8)

### components/ship.gd — pick_health() fix

**Before (broken):**
```gdscript
func pick_health(item: Item):
    storage.add_item(item)   # BUG: added to inventory instead of healing
    item.pick()
```

**After (fixed):**
```gdscript
func pick_health(item: Item):
    var heal_amount: int = max_health / 4
    health = min(health + heal_amount, max_health)
    item.pick()
```

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The health-pack item resource and scene are fully functional. The pickup heal path is wired through the existing `picker_body_entered` → `pick_health()` routing that already handles `IT.ItemTypes.HEALTH`.

## Threat Surface Scan

No new trust boundaries introduced. All threat mitigations from the plan's threat register were implemented:
- T-10-02 (overheal): `min(health + heal_amount, max_health)` clamping applied
- T-10-03 (particle DoS): `amount = 12` kept low as specified

## Self-Check: PASSED

- [x] `items/health-pack.tres` exists with `type = 3` and `name = "health-pack"`
- [x] `prefabs/health-pack/health-pack.tscn` exists with `collision_layer = 32`, CrossH, CrossV, PointLight2D, CPUParticles2D
- [x] `components/ship.gd` pick_health() contains `max_health / 4` and `min(health +` and no `storage.add_item`
- [x] Commit df094e5 exists (Task 1)
- [x] Commit c8de67f exists (Task 2)
