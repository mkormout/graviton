# Roadmap: Graviton

## Milestones

- ✅ **v1.0 Stabilize + Migrate** — Phases 1-3 (shipped 2026-04-10) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v2.0 Enemy AI** — Phases 4-9 (shipped 2026-04-13) — [archive](milestones/v2.0-ROADMAP.md)
- ✅ **v3.0 Quality & Game Systems** — Phases 10-14 (shipped 2026-04-16) — [archive](milestones/v3.0-ROADMAP.md)
- 🚧 **v3.5 Juice & Polish** — Phases 15-18 (in progress)

## Phases

<details>
<summary>✅ v1.0 Stabilize + Migrate (Phases 1-3) — SHIPPED 2026-04-10</summary>

- [x] Phase 1: Bug Fixes (3/3 plans) — completed 2026-04-07
- [x] Phase 2: Code Quality (2/2 plans) — completed 2026-04-07
- [x] Phase 3: Godot 4.6.2 Migration (2/2 plans) — completed 2026-04-10

</details>

<details>
<summary>✅ v2.0 Enemy AI (Phases 4-9) — SHIPPED 2026-04-13</summary>

- [x] Phase 4: EnemyShip Infrastructure (2/2 plans) — completed 2026-04-11
- [x] Phase 5: Beeliner + WaveManager (2/2 plans) — completed 2026-04-12
- [x] Phase 6: Sniper (2/2 plans) — completed 2026-04-12
- [x] Phase 7: Flanker (2/2 plans) — completed 2026-04-13
- [x] Phase 8: Swarmer (2/2 plans) — completed 2026-04-13
- [x] Phase 9: Suicider (2/2 plans) — completed 2026-04-13

</details>

<details>
<summary>✅ v3.0 Quality & Game Systems (Phases 10-14) — SHIPPED 2026-04-16</summary>

- [x] Phase 10: Health Pack Foundation (2/2 plans) — completed 2026-04-14
- [x] Phase 11: ScoreManager (2/2 plans) — completed 2026-04-14
- [x] Phase 12: Score HUD (1/1 plan) — completed 2026-04-14
- [x] Phase 13: Leaderboard (2/2 plans) — completed 2026-04-15
- [x] Phase 14: Enemy Balancing + Wave Variety + UI Polish (4/4 plans) — completed 2026-04-16

</details>

### 🚧 v3.5 Juice & Polish (In Progress)

**Milestone Goal:** Transform the raw combat loop into a polished experience with real enemy sprites, dynamic music, and a proper restart flow.

- [ ] **Phase 15: Enemy Sprites** - Replace Polygon2D debug shapes with sprites; per-enemy gem glow
- [x] **Phase 16: Dynamic Music** - MusicManager autoload with wave-driven category selection and cross-fade (completed 2026-04-17)
- [ ] **Phase 17: Game Restart** - Death screen restart resets all systems without reloading the app
- [ ] **Phase 18: Weapons Improvements** - Six weapons improved with distinct mechanics, VFX, balance pass, and live weapon HUD

## Phase Details

### Phase 15: Enemy Sprites
**Goal**: All five enemy types display ship sprites from ships_assets.png with pulsing gem lights scaled to match the player ship
**Depends on**: Phase 14
**Requirements**: SPR-01, SPR-02, SPR-03, SPR-04, SPR-05
**Success Criteria** (what must be TRUE):
  1. All five enemy types (Beeliner, Sniper, Flanker, Swarmer, Suicider) show a distinct ship sprite from ships_assets.png instead of a colored polygon
  2. If the sprite region is not found or the atlas is missing, the enemy falls back to its existing Polygon2D shape with no crash
  3. Each enemy has a pulsing PointLight2D at its gem position; light color matches the gem color and pulses at a visible rhythm
  4. Gem lights are distance-culled so performance does not degrade at wave 20 with many enemies on screen
  5. Enemy apparent size on screen matches the player ship's apparent size
**Plans**: 4 plans
- [x] 15-01-PLAN.md — Add sprite + gem-light setup logic to all five enemy scripts
- [x] 15-02-PLAN.md — Add GemLight + VisibleOnScreenNotifier2D + GradientTexture2D to all five enemy ship scenes
- [x] 15-03-PLAN.md — Add atlas Sprite2D region to all four firing-enemy bullet scenes
- [ ] 15-04-PLAN.md — Editor atlas-region verification and wave-20 FPS playtest checkpoint
**UI hint**: yes

### Phase 16: Dynamic Music
**Goal**: A MusicManager autoload plays background music that shifts category automatically as wave difficulty escalates, with smooth cross-fades between tracks
**Depends on**: Phase 15
**Requirements**: MUS-01, MUS-02, MUS-03, MUS-04, MUS-05
**Success Criteria** (what must be TRUE):
  1. Music begins playing automatically when the game starts with no player action required
  2. The music system loads tracks from a preload catalog without using DirAccess (export-safe)
  3. Tracks are grouped into Ambient, Combat, and High-Intensity categories; the active category changes as wave number increases
  4. When the active category changes, the outgoing track fades out while the incoming track fades in; the transition sounds smooth, not abrupt
**Plans**: 2 plans
- [x] 16-01-PLAN.md — Import MP3s, create MusicManager autoload, register in project.godot
- [x] 16-02-PLAN.md — Wire MusicManager to WaveManager in world.gd and verify end-to-end

### Phase 17: Game Restart
**Goal**: Players can restart the full game from the death screen; all systems (wave, score, music, enemies) reset to Wave 1 state without reloading the application
**Depends on**: Phase 16
**Requirements**: UI-05, UI-06, UI-07
**Success Criteria** (what must be TRUE):
  1. A "Play Again" button is present and clickable on the death screen
  2. Clicking "Play Again" clears all living enemies, resets the wave to Wave 1, and restores the player to full health — the game is immediately playable
  3. Score, kill count, and wave multiplier reset to zero; the leaderboard is not affected
  4. Music resets to Ambient intensity at the restart; the correct category plays from the start of Wave 1
**Plans**: 2 plans
- [ ] 17-01-PLAN.md — Add reset() to WaveManager and ScoreManager
- [ ] 17-02-PLAN.md — Add Play Again button to DeathScreen, implement _restart_game() in world.gd
**UI hint**: yes

### Phase 18: Weapons Improvements
**Goal**: All six player weapons have distinct mechanics, visual effects, and balanced damage; the recoil bug is fixed; a live weapon HUD shows ammo, reload, and charge/spool state
**Depends on**: Phase 17
**Requirements**: WPN-01 through WPN-11
**Success Criteria** (what must be TRUE):
  1. Firing any weapon no longer causes the ship to spin — recoil applies a clean backward push
  2. Gausscannon: hold fire charges for up to 2s; releasing fires a scaled shot with PointLight2D glow and spark burst at full charge
  3. RPG: passively acquires a lock on enemies in a 30-degree cone (1.5s); locked shots home to target with a red bracket UI
  4. Minigun: fire rate ramps from base to 5x over 2s; damage increases 1.5x at max spool with glow effect
  5. Laser: bullets bounce up to 3 times, spawning 2 children per bounce (up to 8 bullets) with a green flash at each contact
  6. GravityGun: hold fire charges for up to 1.5s; both shockwave force and Area2D radius scale with charge
  7. All weapons produce a muzzle flash; heavy weapons (Gausscannon, RPG, GravityGun) trigger screen shake
  8. All non-laser bullets leave a visible trail and produce a spark burst on impact
  9. Weapon HUD is always visible showing active weapon name, ammo count, reload bar, and charge/spool bar
**Plans**: 10 plans
- [x] 18-01-PLAN.md — Recoil bug fix (mountable-body.gd) + BodyCamera.shake() method
- [x] 18-02-PLAN.md — Laser bouncing bullet (CharacterBody2D reclassing with move_and_collide)
- [ ] 18-03-PLAN.md — GausscannonWeapon: hold-to-charge script + scene PointLight2D/CPUParticles2D
- [ ] 18-04-PLAN.md — RpgWeapon: homing lock acquisition + rpg-bullet.gd homing steering
- [ ] 18-05-PLAN.md — MinigunWeapon: spooling fire rate + glow/particle scaling
- [ ] 18-06-PLAN.md — GravityGun: hold-to-charge update to gravitygun-script.gd
- [ ] 18-07-PLAN.md — Muzzle flash CPUParticles2D for all five weapon scenes + LaserWeapon script
- [ ] 18-08-PLAN.md — Bullet trail (Line2D) + impact FX + laser bounce flash scenes
- [ ] 18-09-PLAN.md — Balance pass: update damage values in Gausscannon, RPG, Laser bullet scenes
- [ ] 18-10-PLAN.md — WeaponHud scene + script + world.gd integration + screen shake wiring (human verify)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Bug Fixes | v1.0 | 3/3 | Complete | 2026-04-07 |
| 2. Code Quality | v1.0 | 2/2 | Complete | 2026-04-07 |
| 3. Godot 4.6.2 Migration | v1.0 | 2/2 | Complete | 2026-04-10 |
| 4. EnemyShip Infrastructure | v2.0 | 2/2 | Complete | 2026-04-11 |
| 5. Beeliner + WaveManager | v2.0 | 2/2 | Complete | 2026-04-12 |
| 6. Sniper | v2.0 | 2/2 | Complete | 2026-04-12 |
| 7. Flanker | v2.0 | 2/2 | Complete | 2026-04-13 |
| 8. Swarmer | v2.0 | 2/2 | Complete | 2026-04-13 |
| 9. Suicider | v2.0 | 2/2 | Complete | 2026-04-13 |
| 10. Health Pack Foundation | v3.0 | 2/2 | Complete | 2026-04-14 |
| 11. ScoreManager | v3.0 | 2/2 | Complete | 2026-04-14 |
| 12. Score HUD | v3.0 | 1/1 | Complete | 2026-04-14 |
| 13. Leaderboard | v3.0 | 2/2 | Complete | 2026-04-15 |
| 14. Enemy Balancing + Wave Variety + UI Polish | v3.0 | 4/4 | Complete | 2026-04-16 |
| 15. Enemy Sprites | v3.5 | 3/4 | In Progress|  |
| 16. Dynamic Music | v3.5 | 2/2 | Complete    | 2026-04-18 |
| 17. Game Restart | v3.5 | 0/2 | Not started | - |
| 18. Weapons Improvements | v3.5 | 0/10 | Planned | - |
