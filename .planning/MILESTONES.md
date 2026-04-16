# Milestones

## v3.0 Quality & Game Systems (Shipped: 2026-04-16)

**Phases completed:** 5 phases, 11 plans, 18 tasks  
**Timeline:** 3 days (2026-04-14 → 2026-04-16)  
**Scope:** 7,915 insertions across 62 files

**Key accomplishments:**

- Health Pack item with procedural green cross + particle aura; ~10% drop from all 5 enemy types including new Suicider CoinDropper
- ScoreManager autoload: per-enemy kill scores, wave multiplier (x1–x16, resets on damage), 5-second combo chain with semitone pitch audio
- Score HUD: CanvasLayer with SCORE/KILLS/MULT/COMBO rows, tween-animated flash on score change and gold pulse on multiplier update
- Leaderboard: death-screen overlay with name entry, ConfigFile-persisted top-10 high scores, gold current-run row, pre-filled last name
- Enemy stat buffs (HP ×2, range ×2, bullet speed ×1.4) and Polygon2D vertex-forward orientation for all 5 types
- Per-type behavioral tweaks: Beeliner jitter pathing, Sniper strafing, Flanker patrol-resume fix, Swarmer fast/slow speed tiers
- Wave flow refactor: manual advance (Enter/F), WaveClearLabel with tween, wave announcement subtitle listing enemy types
- ControlsHint scene with TAB toggle and updated v3.0 shortcut list

---

## v2.0 Enemy AI (Shipped: 2026-04-13)

**Phases completed:** 6 phases, 12 plans, 21 tasks  
**Timeline:** 3 days (2026-04-11 → 2026-04-13)  
**Scope:** 932 insertions across 13 .gd files

**Key accomplishments:**

- EnemyShip base class — 8-state machine, dying guard, force-based steering, detection wiring via Area2D
- Beeliner + WaveManager — full spawn-detect-fight-die-loot-wave-complete pipeline using `tree_exiting` signal for deferred-free-safe wave counting
- Sniper — three-band standoff distance management, aim-up telegraph (two-timer pattern), FLEEING state with safe_range recovery
- Flanker — tangential+radial orbital LURKING state with per-instance CW/CCW randomization, hysteresis-gated FIGHTING burst fire
- Swarmer — angle-offset cluster approach, proximity cohesion via CohesionArea, separation forces; plus Wave HUD and enemy radar UI added
- Suicider — locked-vector torpedo mechanic, ContactArea2D contact detonation, backward-compatible `hit_ships` export patch to explosion.gd; Polygon2D visual identity established for all 5 enemy types

---

## v1.0 Stabilize + Migrate (Shipped: 2026-04-10)

**Phases completed:** 3 phases, 7 plans, 14 tasks

**Key accomplishments:**

- RayCast2D collision damage grounded in physics with speed-scaled kinetic, and reload signal de-duplicated with CONNECT_ONE_SHOT and is_reloading() guard
- Editor-wired @export var spawn_parent: Node replaces all 7 fragile get_tree().current_scene calls across 6 component files, with null guards and push_warning fallbacks
- spawn_parent wired entirely in code via recursive propagation helpers; all spawn sites (bullets, explosions, asteroid fragments, item drops, coin pickups) verified working
- Eliminated per-frame find_children() call in get_mount() by iterating the pre-cached mounts array, and removed noisy drag-and-drop debug print from inventory-slot.gd
- Replaced all raw string action literals with typed MountableBody.Action enum across 4 files — typos in action dispatch now produce GDScript parse errors instead of silent no-ops
- Four deprecated string-based connect() calls replaced with signal-object syntax and Linux export preset updated to Godot 4.3+ platform identifier
- Godot project migrated to 4.6.2: editor conversion applied, 30 UID files committed, smoke test and 4-platform local export verified

---
