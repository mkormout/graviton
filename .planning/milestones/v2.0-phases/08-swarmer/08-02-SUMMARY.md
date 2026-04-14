---
plan: 08-02
phase: 08-swarmer
status: complete
---

# Plan 08-02 Summary: Swarmer Scene + World Wiring

## What was built

**Task 1 — `prefabs/enemies/swarmer/swarmer.tscn`**
Flat enemy scene (same pattern as Flanker/Sniper/Beeliner) with all nodes required by swarmer.gd:
- Root RigidBody2D with swarmer.gd script, collision_mask=3, gravity_scale=0.0
- max_health=15 (weakest enemy), max_speed=1800, thrust=1200
- CohesionArea (Area2D, layer=0, mask=1, monitorable=false, radius=900)
- FireTimer (wait_time=0.8), Barrel at (350,0), CoinDropper, AmmoDropper
- DetectionArea, HitBox (mask=4), CollisionShape2D, Sprite2D

**Task 2 — `world.gd` WaveManager wiring**
- Added `swarmer_model` preload and 5-enemy Swarmer wave as wave 2 in WaveManager.waves

**Playtest feedback addressed (commit 82eb820)**

Swarmer cohesion overhaul:
- Added `cohesion_force = 700` pulling swarmers toward group center
- Increased `separation_force` 800→1800 for more personal space
- Increased `cohesion_radius` 700→900 for earlier swarm detection
- `_compute_force_scale()` now ramps smoothly (lerp) based on nearest neighbor distance — seamless join transition
- `_apply_cohesion()` attracts toward group center; force scales with distance so swarmers pull hardest at swarm edge

Wave status HUD (`prefabs/ui/wave-hud.gd`, `prefabs/ui/wave-hud.tscn`):
- Top-center Panel: "WAVE N" + "remaining / total"
- Hidden until first wave; shows "ALL CLEAR" when all waves done
- Connected to WaveManager signals

Enemy radar (`prefabs/ui/enemy-radar.gd`, `prefabs/ui/enemy-radar.tscn`):
- Red triangular arrows on screen border pointing to off-screen enemies
- Draws via Control._draw() each frame

WaveManager additions:
- Signals: `wave_started`, `enemy_count_changed`, `all_waves_complete`
- Spawned enemies added to "enemy" group for radar queries

## Key files

- `prefabs/enemies/swarmer/swarmer.tscn` — Swarmer enemy scene
- `components/swarmer.gd` — Updated with cohesion_force + smooth transitions
- `components/wave-manager.gd` — Signals + enemy group tagging
- `prefabs/ui/wave-hud.gd` / `wave-hud.tscn` — Wave status UI
- `prefabs/ui/enemy-radar.gd` / `enemy-radar.tscn` — Screen-border enemy arrows
- `world.gd` — Preloads + instantiation of both UI components

## Commits

- `2982edb` feat(08-02): create swarmer.tscn enemy scene
- `1f2f15e` feat(08-02): wire Swarmer into world.gd WaveManager
- `82eb820` feat(08-02): playtest improvements — cohesion, wave HUD, enemy radar
