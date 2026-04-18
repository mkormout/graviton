# Graviton

## What This Is

A 2D space shooter built in Godot 4.6.2, featuring a component-based ship architecture with hot-swappable weapon mounts, an inventory system, procedurally scattered asteroids, and wave-based enemy ships with state-machine-driven AI. The player pilots a ship, equips weapons from inventory, battles five distinct enemy types, and chases high scores tracked on a local leaderboard.

## Core Value

The mount-and-weapon system must work reliably — ships can equip, fire, and swap weapons without bugs or silent failures.

## Current Milestone: v3.5 Juice & Polish

**Goal:** Transform the raw combat loop into a polished experience with real enemy sprites, dynamic music, and a proper restart flow.

**Target features:**
- Game Restart — reset wave/score/state from the death screen without reloading the app
- Dynamic Music System — background audio that adapts to wave complexity; auto-scans /music folder; categories: Ambient/Combat/High-Intensity; cross-fade transitions
- Enemy Sprites — replace all 5 Polygon2D debug shapes with sprites from ships_assets.png; per-enemy gem glow pulsing light; fallback to debug shape if unavailable; scale to match player ship

## Requirements

### Validated

- ✓ Player ship is controllable and movable — existing
- ✓ Weapons can be mounted/unmounted at runtime — existing
- ✓ Multiple weapon types (minigun, laser, gausscannon, RPG, gravitygun) — existing
- ✓ Inventory system with drag-and-drop UI — existing
- ✓ Asteroids spawn and collide with ships — existing
- ✓ Item drops (coins, ammo, weapons, health) — existing
- ✓ Ammo tracking and reload system — existing
- ✓ Collision damage fires correctly with accurate contact position — v1.0 (BUG-01)
- ✓ Reload signal does not stack duplicate connections — v1.0 (BUG-02)
- ✓ Spawn parents use stable node references instead of `get_tree().current_scene` — v1.0 (BUG-03)
- ✓ Action dispatch uses typed constants instead of raw strings — v1.0 (QUA-01)
- ✓ Mount lookup does not call `find_children()` every physics frame — v1.0 (QUA-02)
- ✓ Debug `print()` statements removed from hot paths — v1.0 (QUA-03)
- ✓ Game runs correctly on Godot 4.6.2 — v1.0 (MIG-01, MIG-02, MIG-03)
- ✓ Abstract EnemyShip base class with virtual state-machine methods — v2.0 (ENM-01–ENM-06, ENM-15)
- ✓ State machine with 8 states; concrete enemies implement their relevant subset — v2.0
- ✓ Beeliner enemy — charges and fires at player — v2.0 (ENM-07)
- ✓ Sniper enemy — keeps distance, fires slow heavy shots, flees when approached — v2.0 (ENM-08)
- ✓ Flanker enemy — circles player before engaging — v2.0 (ENM-09)
- ✓ Swarmer enemy — weak alone, cluster attack with cohesion — v2.0 (ENM-10)
- ✓ Suicider enemy — charges and explodes on contact — v2.0 (ENM-11)
- ✓ Simplified enemy fire logic (independent of MountableWeapon/inventory) — v2.0
- ✓ Wave-based enemy spawning system with WaveManager — v2.0 (ENM-12, ENM-13, ENM-14)
- ✓ Health Pack item drops from enemies with green cross visuals and heal-on-pickup — v3.0 (ITM-01–ITM-03)
- ✓ ScoreManager autoload with per-enemy kill scores, wave multiplier (x1–x16), and 5-second combo chain with semitone audio — v3.0 (SCR-03–SCR-08)
- ✓ Score HUD displaying score, kill count, and wave multiplier with tween animations — v3.0 (SCR-01, SCR-02, SCR-05)
- ✓ Death screen with name entry, ConfigFile-persisted top-10 leaderboard, and last-name pre-fill — v3.0 (SCR-09–SCR-11)
- ✓ All enemies buffed (HP ×2, range ×2, speed ×1.4) with Polygon2D vertex-forward orientation — v3.0 (ENM-16–ENM-20)
- ✓ Per-type behavioral tweaks: Beeliner jitter, Sniper strafe, Flanker patrol fix, Swarmer speed tiers, Suicider explosion buff — v3.0 (ENM-21–ENM-25)
- ✓ Wave flow refactor: manual advance, WaveClearLabel, wave announcement subtitle — v3.0 (WAV-01, WAV-02)
- ✓ ControlsHint scene with TAB toggle and updated shortcut list — v3.0 (UI-01–UI-04)

### Active

- [ ] **UI-05**: Player can restart the game from the death screen without reloading the application
- [ ] **MUS-01**: Background music plays automatically when the game starts
- [ ] **MUS-02**: Music system scans /music folder and loads all audio files automatically
- [ ] **MUS-03**: Tracks are categorized (Ambient, Combat, High-Intensity) for wave-driven selection
- [ ] **MUS-04**: Music transitions dynamically based on current wave complexity
- [ ] **MUS-05**: Tracks cross-fade smoothly when switching categories
- [ ] **SPR-01**: ENM-07 through ENM-11 display sprite from ships_assets.png instead of Polygon2D
- [ ] **SPR-02**: Sprite sheet slicing extracts individual ship sprites programmatically
- [ ] **SPR-03**: Fallback to Polygon2D debug shape when sprite is unavailable
- [ ] **SPR-04**: Each enemy ship's gem emits a pulsing light matching the gem's color
- [ ] **SPR-05**: Enemy sprite scale matches player ship size

### Out of Scope

- Multiplayer — not planned
- Procedural level generation — not planned
- Automated test suite (GUT) — user opted for manual playtesting
- Flocking / Boids behavior — deferred to v3.0 or later
- Predictive targeting for Sniper — deferred
- Pre-wave HUD announcement and audio sting — deferred
- Escort / Patrol state implementation — deferred
- NavigationAgent2D pathfinding — no nav mesh in open space; regression risk

## Context

Godot 4.6.2 project. ~15,244 LOC GDScript across components and prefabs.

Five enemy types (Beeliner, Sniper, Flanker, Swarmer, Suicider) with 8-state AI, Polygon2D visual identity, and per-type behavioral tuning. All buffed in v3.0: HP ×2, range ×2, bullet speed ×1.4, vertex-forward orientation.

ScoreManager autoload drives kill scoring, wave multiplier (x1–x16), and combo chain. Score HUD (CanvasLayer) shows SCORE/KILLS/MULT/COMBO in real time. Death screen shows leaderboard with ConfigFile-persisted top-10 entries.

WaveManager supports manual wave advance (Enter/F), with WaveClearLabel and wave announcement subtitles. ControlsHint panel lists all shortcuts and toggles with TAB.

`world.gd` remains a developer test harness with no main menu or persistent game loop. Health packs drop from enemies at ~10% chance.

## Constraints

- **Engine**: Godot 4.6.2 (GDScript) — no C# or other language targets
- **Enemy fire**: Simplified, not using MountableWeapon/inventory layer
- **Spawning**: Wave-based

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Enemy AI deferred to v2.0 | Approach not yet decided; not blocking stabilization | ✓ Good — clean foundation ready |
| Milestone order: fix → migrate → AI | Migration is easier on clean code; bugs should be fixed before upgrading | ✓ Good — paid off |
| speed / 10.0 kinetic damage formula | Gives 100 damage at 1000 px/s as playtesting baseline | ✓ Good — felt fair in v2.0 playtesting |
| CONNECT_ONE_SHOT for reload signal | Simpler than manual disconnect; idiomatic Godot 4 | ✓ Good |
| @export spawn_parent propagation | Stable scene reference; null guards + push_warning for safety | ✓ Good |
| MountableBody.Action enum | Parse-time typo detection vs. silent string mismatch | ✓ Good |
| Enemy fire simplified (no MountableWeapon) | Reduces coupling; easier to balance enemy difficulty independently | ✓ Good — each type tunes independently |
| Wave-based spawning | Classic arcade feel; predictable difficulty scaling | ✓ Good — WaveManager clean and extensible |
| No fire loop in EnemyShip base class | Concrete types implement fire independently | ✓ Good — Suicider has no fire, others vary freely |
| HitBox Area2D (mask=4) for bullet detection | Avoids modifying all bullet scenes | ✓ Good |
| tree_exiting signal for wave completion | Handles deferred queue_free correctly | ✓ Good — no missed deaths |
| Flat scene for enemy types (not true inheritance) | Avoids Godot .tscn inheritance complications | ✓ Good |
| ContactArea2D separate from DetectionArea in Suicider | Clean separation of target acquisition vs. contact detection | ✓ Good |
| Polygon2D visual identity per enemy type | Could not distinguish enemies visually at a glance during playtest | ✓ Good — added in Phase 9 playtest |
| ScoreManager as autoload singleton | Avoids signal plumbing through world.gd; any node can read score state | ✓ Good — clean integration |
| ConfigFile for leaderboard persistence | Built-in Godot API, no external deps, cross-platform | ✓ Good |
| Two-stage death screen (name entry → leaderboard) | Separates concerns; name can be skipped without breaking leaderboard display | ✓ Good |
| Wave multiplier resets on any damage | High-risk reward loop; felt fair in playtesting | ✓ Good |
| Manual wave advance (Enter/F) instead of auto-timer | Gives player breathing room; reduces frustration at high waves | ✓ Good — confirmed in playtesting |
| speed_tier injection per wave config | Lets WaveManager vary swarmer behavior without subclassing | ✓ Good — clean extensibility |
| Vertex-forward Polygon2D via fixed rotation offset | All enemy shapes face player with a corner, not a flat edge | ✓ Good — visual improvement confirmed |

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
*Last updated: 2026-04-18 — Phase 16 complete (dynamic music system with cross-fade)*
