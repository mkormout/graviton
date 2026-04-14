# Phase 5: Beeliner + WaveManager - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the Beeliner — the first concrete enemy type — and the WaveManager that spawns and tracks enemy waves. Proves the full pipeline end-to-end: spawn outside viewport → seek → transition to FIGHTING → fire shotgun burst → die → drop loot → WaveManager detects wave completion. No other enemy types in this phase.

Requirements covered: ENM-07, ENM-12, ENM-13, ENM-14.

</domain>

<decisions>
## Implementation Decisions

### Beeliner bullet (ENM-07)
- **D-01:** Create a new `beeliner-bullet.tscn` — a structural copy of `minigun-bullet.tscn` with its own `Damage` resource. Sprite will be provided by user later; leave Sprite2D blank for now.
- **D-02:** Beeliner fires a shotgun burst: **3 bullets simultaneously at ~15° spread** (one center, one +7.5°, one -7.5° from barrel aim direction).
- **D-03:** Fire rate: **one burst every 1.5 seconds** while in FIGHTING state, using a Timer node.
- **D-04:** Bullet spawning follows the established pattern: `spawn_parent.add_child(bullet)` at `$Barrel.global_position` (ENM-05). Beeliner owns its own Timer, bullet instantiation, and barrel position logic — no base class fire loop.

### Beeliner visuals
- **D-05:** No sprite in Phase 5. Beeliner inherits the base class `_draw` debug indicator (red circle + direction arrow + state label). Real sprite will be added when the user provides the asset.

### WaveManager (ENM-12, ENM-13, ENM-14)
- **D-06:** `WaveManager` is a standalone `Node` child of the World root (not a ship, not a physics body).
- **D-07:** Wave composition is defined as `@export var waves: Array[Dictionary]` where each entry has `{ "enemy_scene": PackedScene, "count": int }`. Configurable in the Godot editor without code changes — extensible for Phases 6–9.
- **D-08:** Wave completion is tracked by a counter (`_enemies_alive: int`) decremented via a signal connection on each enemy's `tree_exiting` (or equivalent death signal) — **not** by `get_children()` count, to handle deferred frees correctly (ENM-13).
- **D-09:** Enemies are spawned with a minimum outer-radius margin from the viewport edge and from each other's spawn positions, to prevent physics-separation launch on the first frame (ENM-14). Spawn zone: random positions outside the visible area (player-centered viewport radius + margin).
- **D-10:** Wave trigger: `WaveManager` exposes a `trigger_wave()` method. `world.gd` calls it via a keyboard shortcut (consistent with existing dev keys like Enter=asteroids, G=godmode). Choose a key not already taken — `KEY_W` or similar.

### Loot drops
- **D-11:** Beeliner drop table (configured in ItemDropper node in the inherited scene):
  - 1–2 `coin-copper.tscn` — always drops (weight 1.0 each, `drop_count` set to ensure 1–2)
  - 1 `minigun-ammo` item — 50% chance (weight 0.5 relative to a no-drop entry)
- **D-12:** Use existing item resources: `items/coin-copper.tres` and `items/minigun-ammo.tres`. No new item types needed.

### Claude's Discretion
- Exact bullet speed and `Damage.energy` value for Beeliner bullet (tune to be roughly comparable to minigun — adjust in playtesting)
- Exact spawn margin radius value (ENM-14 says "minimum outer-radius margin" — a sensible default like viewport half-diagonal + 200px)
- Whether to use `tree_exiting` or a custom `died` signal for wave counter decrement (whichever is simpler given the existing `Body.die()` / `queue_free()` chain)
- The exact keyboard key for wave trigger (not already in use in `world.gd`)

</decisions>

<specifics>
## Specific Ideas

- Shotgun burst feel: user envisions Beeliner firing multiple projectiles at once "in short time range" — all 3 bullets instantiated in a single `_fire()` call, not staggered sub-timers.
- Sprite is deferred — no art blocker for Phase 5.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — ENM-07, ENM-12, ENM-13, ENM-14: full acceptance criteria for Phase 5
- `.planning/ROADMAP.md` §Phase 5 — Goal, success criteria, and phase boundary

### Base class (read before extending)
- `components/enemy-ship.gd` — Full EnemyShip base class: State enum, `_change_state`, `steer_toward`, dying guard, detection wiring, fire pattern comment at bottom
- `prefabs/enemies/base-enemy-ship.tscn` — Scene to inherit from: root node + CollisionShape2D + Sprite2D + DetectionArea + HitBox + Barrel + ItemDropper structure

### Existing patterns to replicate
- `components/item-dropper.gd` — `drop()`, `roll()`, `ItemDrop` model: how to configure models/chance/drop_count for the loot table (D-11, D-12)
- `prefabs/minigun/minigun-bullet.tscn` — Scene structure to copy for `beeliner-bullet.tscn` (D-01)
- `components/bullet.gd` — Bullet class used by minigun bullet; Beeliner bullet should use the same or extend it

### Physics layers
- `world.gd` lines 28–36 — Physics layer table (Ship=1, Weapons=2, Bullets=3, Asteroids=4, Explosions=5, Coins=6, Ammo=7, WeaponItem=8) — Beeliner bullet must be on layer 3, masked to hit Ship (1)

### Existing item resources (for ItemDropper configuration)
- `items/coin-copper.tres` — COIN type item resource
- `items/minigun-ammo.tres` — AMMO type item resource

### World integration
- `world.gd` — Where WaveManager is added as a child node and where the trigger keyboard shortcut is wired (D-10); check existing key bindings before choosing the trigger key

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `EnemyShip.steer_toward(target_position)` — already implements `apply_central_force` steering; Beeliner SEEKING uses this directly
- `EnemyShip._change_state(new_state)` — already handles exit/enter/print; Beeliner just calls this
- `ItemDropper.drop()` — fully functional; just configure `models`, `drop_count`, and `spawn_parent`
- `Body.dying` flag + `queue_free()` chain — the signal to connect for wave counter decrement is emitted during this death sequence

### Established Patterns
- `spawn_parent.add_child()` bullet spawning (not `get_tree().current_scene`) — MANDATORY per ENM-05 / D-04
- `@export` for all tunable values (max_speed, thrust, detection_radius, fire_rate) — concrete type configures via Godot editor
- Scene inheritance: `beeliner.tscn` inherits `base-enemy-ship.tscn` — override Sprite2D texture and `@export` defaults, nothing else required structurally
- No picker `Area2D` in enemy scenes — inherited scene already omits it (ENM-15, D-02 from Phase 4)

### Integration Points
- `world.gd._ready()`: call `setup_spawn_parent($WaveManager)` (or equivalent) so WaveManager-spawned enemies get correct spawn_parent
- `world.gd._input(ev)`: add `KEY_W` (or chosen key) check to call `$WaveManager.trigger_wave()`
- `EnemyShip._on_detection_area_body_entered`: already transitions IDLING → SEEKING when PlayerShip enters detection area — Beeliner needs to add SEEKING → FIGHTING transition in `_tick_state` when close enough

</code_context>

<deferred>
## Deferred Ideas

- Beeliner sprite — user will provide asset later; Phase 5 uses debug _draw placeholder
- Pre-wave HUD announcement and audio sting — deferred to v2.1+ (in REQUIREMENTS.md)
- Wave auto-advance (WaveManager auto-triggers next wave after completion) — out of scope for Phase 5; trigger is manual keyboard shortcut

</deferred>

---

*Phase: 05-beeliner-wavemanager*
*Context gathered: 2026-04-12*
