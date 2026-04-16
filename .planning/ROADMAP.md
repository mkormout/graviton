# Roadmap: Graviton

## Milestones

- ✅ **v1.0 Stabilize + Migrate** — Phases 1-3 (shipped 2026-04-10) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v2.0 Enemy AI** — Phases 4-9 (shipped 2026-04-13) — [archive](milestones/v2.0-ROADMAP.md)
- ✅ **v3.0 Quality & Game Systems** — Phases 10-14 (shipped 2026-04-16) — [archive](milestones/v3.0-ROADMAP.md)
- 🚧 **v3.5 Juice & Polish** — Phases 15-17 (in progress)

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
- [ ] **Phase 16: Dynamic Music** - MusicManager autoload with wave-driven category selection and cross-fade
- [ ] **Phase 17: Game Restart** - Death screen restart resets all systems without reloading the app

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
**Plans**: TBD
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
**Plans**: TBD

### Phase 17: Game Restart
**Goal**: Players can restart the full game from the death screen; all systems (wave, score, music, enemies) reset to Wave 1 state without reloading the application
**Depends on**: Phase 16
**Requirements**: UI-05, UI-06, UI-07
**Success Criteria** (what must be TRUE):
  1. A "Play Again" button is present and clickable on the death screen
  2. Clicking "Play Again" clears all living enemies, resets the wave to Wave 1, and restores the player to full health — the game is immediately playable
  3. Score, kill count, and wave multiplier reset to zero; the leaderboard is not affected
  4. Music resets to Ambient intensity at the restart; the correct category plays from the start of Wave 1
**Plans**: TBD
**UI hint**: yes

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
| 15. Enemy Sprites | v3.5 | 0/TBD | Not started | - |
| 16. Dynamic Music | v3.5 | 0/TBD | Not started | - |
| 17. Game Restart | v3.5 | 0/TBD | Not started | - |
