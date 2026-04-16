# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Stabilize + Migrate

**Shipped:** 2026-04-10
**Phases:** 3 | **Plans:** 7

### What Was Built

- Fixed RayCast2D collision damage — ray now added to scene tree before query, speed-scaled kinetic damage (speed/10.0)
- Fixed reload signal stacking — CONNECT_ONE_SHOT + is_reloading() guard eliminates duplicate reload cycles
- Replaced all `get_tree().current_scene` spawn parent references with `@export var spawn_parent` propagated recursively through the mount hierarchy
- Eliminated per-frame `find_children()` in `get_mount()` by iterating the pre-cached mounts array
- Replaced string action literals with typed `MountableBody.Action` enum — typos now cause parse errors
- Removed debug print from inventory drag-and-drop hot path
- Migrated project from Godot 4.2.1 to 4.6.2: deprecated connect() calls updated, UID files generated, 4-platform export verified

### What Worked

- Planning bugs before coding caught the full scope (3 bugs vs. guessing one at a time)
- Code review pass on Phase 3 caught 3 additional issues (null guards, invalid bundle ID) that smoke test missed
- Splitting migration into pre-migration fixes (03-01) + editor conversion (03-02) kept each plan small and focused

### What Was Inefficient

- REQUIREMENTS.md traceability table was never updated during execution — all requirements stayed "Pending" despite being shipped
- STATE.md progress tracking drifted from reality (showed 0% complete while phases were finishing)

### Patterns Established

- `@export var spawn_parent: Node` with recursive propagation via mount hierarchy — use this for any node that needs to spawn children into the game world
- `CONNECT_ONE_SHOT` for one-time signal handlers (reload, death) instead of manual disconnect
- `MountableBody.Action` enum — all new action strings must be added as enum values, not raw strings
- Pre-migration deprecation pass as a separate plan before engine conversion

### Key Lessons

1. Keep the traceability table updated during execution, not just at milestone close
2. Code review after migration catches issues the smoke test skips (editor doesn't run all code paths)
3. Godot 4.x migration generates UID files for every script/scene — commit them as a single dedicated commit to keep the diff readable

---

## Milestone: v2.0 — Enemy AI

**Shipped:** 2026-04-13
**Phases:** 6 | **Plans:** 12

### What Was Built

- EnemyShip base class — 8-state machine, dying guard, `apply_central_force` steering, DetectionArea wiring
- Beeliner + WaveManager — full pipeline: spawn → seek → fight → die → drop loot → wave complete; `tree_exiting` signal handles deferred queue_free safely
- Sniper — three-band distance management, two-timer aim-up telegraph, FLEEING with safe_range recovery
- Flanker — tangential+radial orbital LURKING with per-instance CW/CCW/radius randomization, hysteresis-gated FIGHTING bursts
- Swarmer — angle-offset approach vectors, proximity CohesionArea, linear-falloff separation; Wave HUD + screen-border enemy radar UI added as bonus
- Suicider — locked-vector torpedo, ContactArea2D detonation, backward-compatible `hit_ships` export on explosion.gd; Polygon2D visual identity added for all 5 types during playtest

### What Worked

- One enemy type per phase kept complexity manageable — each type built cleanly on the last
- `tree_exiting` for wave counting was the right call — caught during Phase 5 research, prevented a subtle deferred-free bug
- Iterative playtest tuning committed atomically (Phase 9 had 9 tuning commits) — easy to bisect if needed
- HitBox Area2D pattern (mask=4) for bullet detection avoided touching all bullet scenes
- Phase 9 was the fastest execution (2 min for 09-01) — base patterns fully established by then

### What Was Inefficient

- REQUIREMENTS.md traceability again never updated during execution (same issue as v1.0)
- Visual identity (Polygon2D) was not planned — discovered during Phase 9 playtest; had to retroactively add shapes to all enemy scenes. Should be part of the scene scaffold for v3.0 enemies
- No formal verification/audit before milestone close — proceeded with known gaps flag

### Patterns Established

- Enemy scene pattern: flat scene (not Godot inheritance) extending base-enemy-ship.tscn, script override, FireTimer + CoinDropper + AmmoDropper, no picker Area2D
- Enemy bullet layer: collision_layer=256 (Layer 9), collision_mask=1 (Ship) — prevents friendly fire without modifying existing bullet scenes
- Two-timer fire pattern (FireTimer → AimTimer → _fire()) for telegraphed shots
- `_reacquire_target()` bypass for EnemyShip idempotency guard when re-locking without state change
- Polygon2D as visual identity per enemy type — distinct shape + color per type, no texture needed

### Key Lessons

1. Traceability table needs to be updated *during* execution, not at milestone close — consider adding to phase summary template
2. Enemy visual identity (shape/color) should be scaffolded in base-enemy-ship.tscn for v3.0, not added retroactively
3. The dying guard pattern (early return in _physics_process + all signal handlers) is essential — add it to any future AI base class immediately
4. `tree_exiting` > `get_children().size()` for any counter that must survive deferred frees

---

## Milestone: v3.0 — Quality & Game Systems

**Shipped:** 2026-04-16
**Phases:** 5 | **Plans:** 11

### What Was Built

- Health Pack item — procedural green cross + particle aura, ~10% drop from all 5 enemy types
- ScoreManager autoload — per-enemy kill scores, wave multiplier (x1–x16, resets on damage), 5-second combo chain with semitone pitch progression
- Score HUD — CanvasLayer with SCORE/KILLS/MULT/COMBO rows, tween flash on score and gold pulse on multiplier
- Leaderboard — death-screen overlay, name entry, ConfigFile-persisted top-10, last-name pre-fill, gold current-run highlight
- Enemy stat buffs: HP ×2, range ×2, bullet speed ×1.4, Polygon2D vertex-forward orientation for all 5 types
- Per-type behavioral tweaks: Beeliner jitter pathing, Sniper strafe, Flanker patrol-resume fix, Swarmer fast/slow speed tiers, Suicider explosion buff
- Wave flow refactor: countdown removed, manual advance (Enter/F), WaveClearLabel, wave announcement subtitle listing enemy types
- ControlsHint scene with TAB toggle, updated v3.0 shortcut list

### What Worked

- Splitting Phase 11 into signal scaffolding (11-01) + ScoreManager logic (11-02) kept the autoload clean and testable before HUD existed
- ConfigFile for leaderboard was the right call — zero external deps, built-in Godot API, worked first try
- Manual wave advance (Enter/F) validated immediately in playtesting — players appreciated the breathing room
- speed_tier injection per wave config let WaveManager vary Swarmer behavior without subclassing or new scenes
- Phase 14 playtest checkpoint (Task 3) caught a Ship.pick_health() regression before commit — UAT gate paid off

### What Was Inefficient

- Phase 10 SUMMARY 10-01 extracted as "Before (broken):" — partial summary committed; indicates gsd-tools summary-extract needs a more robust one-liner fallback
- Phase 14 was large (4 plans, 5 concerns) — could have split enemy balancing and wave flow into separate phases for cleaner history
- Several `.uid` files went untracked for the whole milestone (score-manager.gd.uid, controls-hint.gd.uid, etc.) — need to commit UID files immediately when new scripts are added

### Patterns Established

- `ScoreManager` autoload pattern: singleton reads signals from Body/WaveManager/EnemyShip, no signal plumbing through world.gd required
- `PROCESS_MODE_ALWAYS` on death-screen CanvasLayer — required to receive input while tree is paused; use this for any overlay that must work on pause
- `speed_tier` export on EnemyShip base class for per-wave behavioral variance without subclassing
- Vertex-forward Polygon2D: rotate shape -90° (or appropriate offset) so a vertex points in the forward direction

### Key Lessons

1. Commit `.uid` files immediately when new scripts/scenes are created — letting them accumulate as untracked creates noise at milestone close
2. Phase 14 scope was too broad — when a phase has 4+ independent concerns (enemy stats, per-type AI, wave flow, UI), split it during planning
3. ScoreManager as an autoload was the right architecture — all game systems (HUD, leaderboard, audio) connect to it without world.gd becoming a god object

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 3 | 7 | First milestone — established base patterns |
| v2.0 | 6 | 12 | Enemy AI system — one-type-per-phase cadence |
| v3.0 | 5 | 11 | Game systems (scoring, UI, polish) — autoload + CanvasLayer patterns |

### Top Lessons (Verified Across Milestones)

1. Small, focused plans (one concern per plan) complete faster and are easier to review
2. Scaffold identity/debug features early — retroactive additions cost extra commits across all scenes
3. Commit UID files immediately when new scripts/scenes are created — do not let them accumulate
4. Autoload singletons (ScoreManager) keep world.gd from becoming a god object — use for any cross-cutting game state
