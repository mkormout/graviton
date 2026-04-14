# Phase 4: EnemyShip Infrastructure - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the EnemyShip base class that all five concrete enemy types (Phases 5-9) extend. Deliverables: the `enemy-ship.gd` script with state machine scaffold, dying guard, detection Area2D wiring, steering helpers, and a `base-enemy-ship.tscn` skeleton scene. No concrete enemy types in this phase — just the shared foundation.

Requirements covered: ENM-01, ENM-02, ENM-03, ENM-04, ENM-05 (pattern only), ENM-06, ENM-15.

</domain>

<decisions>
## Implementation Decisions

### Picker conflict (ENM-15)
- **D-01:** Add a null guard (`if picker:`) before the `picker.body_entered.connect(...)` call in `Ship._ready()`. Minimal, backwards-compatible — PlayerShip keeps its picker assigned in the scene; EnemyShip scenes simply omit it.
- **D-02:** EnemyShip scenes have no picker `Area2D` node — enemies do not collect items.

### Base scene structure
- **D-03:** Phase 4 delivers both the `enemy-ship.gd` script and a `base-enemy-ship.tscn` skeleton scene. Phases 5-9 use Godot scene inheritance to override visuals and exports.
- **D-04:** The base scene contains a full skeleton: root EnemyShip node + `CollisionShape2D` + `Sprite2D` placeholder + `Area2D` detection node + barrel `Node2D` + `ItemDropper`. No picker `Area2D`.
- **D-05:** Each concrete enemy type (Phase 5+) inherits `base-enemy-ship.tscn` and overrides the sprite texture, collision shape, and @export values.

### Fire loop ownership
- **D-06:** The EnemyShip base class provides **no** fire loop infrastructure. Fire logic (Timer setup, bullet instantiation, barrel positioning) is entirely the responsibility of each concrete enemy type in Phases 5-9.
- **D-07:** Phase 4 establishes the fire pattern as convention only: concrete types use `spawn_parent.add_child()` to instantiate a bullet scene at the barrel `Node2D` position. ENM-05 is validated at Phase 5 (first concrete implementation).
- **D-08:** The barrel `Node2D` is included in the base scene so all concrete types have a consistent reference point — but the base class script does not reference or use it.

### State machine scaffold (ENM-01, ENM-02)
- **D-09:** EnemyShip declares a `State` enum with all 8 values (IDLING, SEEKING, LURKING, FIGHTING, FLEEING, PATROLLING, EVADING, ESCORTING) and a `current_state: State` variable.
- **D-10:** Three virtual methods — `_tick_state(delta)`, `_enter_state(new_state)`, `_exit_state(old_state)` — are defined in the base class with empty default implementations. Concrete types override only the states they use.
- **D-11:** State transitions go through a `_change_state(new_state: State)` helper that calls `_exit_state`, updates `current_state`, then calls `_enter_state`.
- **D-12:** All calls to `_tick_state` and fire-related logic are guarded by `if dying: return` (ENM-02). The `dying` flag already exists on `Body`.

### Detection (ENM-04)
- **D-13:** Detection uses an `Area2D` placed in the base scene. The base class script holds an `@onready` reference (`@onready var detection_area: Area2D = $DetectionArea`).
- **D-14:** Layer and mask bits on the detection `Area2D` are set explicitly, with values documented in an inline comment referencing the physics layer table in `world.gd`.
- **D-15:** `body_entered` on the detection area drives the IDLING → SEEKING transition in the base class. Concrete types can override `_enter_state` / `_tick_state` to handle further transitions.

### Steering (ENM-03)
- **D-16:** Enemy movement uses `apply_central_force()` with a steering vector computed each physics frame. Maximum speed is clamped in `_integrate_forces` using `linear_velocity = linear_velocity.limit_length(max_speed)`. No direct `linear_velocity` assignment anywhere in enemy scripts.
- **D-17:** The base class exposes `@export var max_speed: float` and `@export var thrust: float` so concrete types tune movement via scene exports.

### Debug indicator
- **D-18:** State transitions emit a `print()` log (e.g., `"[EnemyShip] state: IDLING → SEEKING"`) during Phase 4 development. This satisfies success criterion 1 and is removed or gated with a debug flag before Phase 5.

### Claude's Discretion
- Exact `CollisionShape2D` shape in the base scene (circle is fine as a placeholder)
- Sprite2D placeholder texture (leave blank or use a 1×1 white pixel)
- Whether `_tick_state` is called from `_process` or `_physics_process` (either is fine — `_physics_process` preferred for consistency with movement)
- ItemDropper configuration in the base scene (leave all exports unset; concrete types configure)

</decisions>

<specifics>
## Specific Ideas

- No specific visual references given — enemy ship appearance is deferred to concrete enemy phases.
- The fire pattern (Timer + barrel + `spawn_parent.add_child()`) is a convention established here, not enforced by the base class.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — ENM-01 through ENM-06, ENM-15: full acceptance criteria and traceability for Phase 4
- `.planning/ROADMAP.md` §Phase 4 — Goal, success criteria, and phase boundary

### Existing base classes (read before modifying)
- `components/body.gd` — `dying` flag, `die()`, `spawn_parent`, `_propagate_spawn_parent()` — all reused as-is
- `components/ship.gd` — `picker: Area2D` and `_ready()` connection that needs the null guard (D-01)
- `components/enemy-ship.gd` — current stub (2 lines); this is the file being built out
- `components/mountable-body.gd` — `Action` enum pattern, `_physics_process` mount sync — understand before extending

### Physics layers
- `world.gd` lines 28-36 — Physics layer table (Ship=1, Weapons=2, Bullets=3, Asteroids=4, Explosions=5, Coins=6, Ammo=7, WeaponItem=8) — use when setting detection Area2D layer/mask bits

### No external specs
- No ADRs or feature docs beyond the files listed above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Body.dying` flag: already exists — no new field needed for ENM-02 guard
- `Body.spawn_parent` + `_propagate_spawn_parent()`: already propagates to all children — enemy bullet spawning can use this directly
- `components/explosion.gd`: will be used by Suicider (Phase 9) via `body_entered` — no changes needed in Phase 4
- `ItemDropper`: already in Body hierarchy — base scene just includes the node; concrete types configure the drop table

### Established Patterns
- `@export spawn_parent: Node` propagation pattern (not `get_tree().current_scene`) — must be followed for all bullet spawning (ENM-05)
- `apply_central_force` / `_integrate_forces` pattern: used by `PropellerMovement`; enemy steering should follow the same pattern (ENM-03)
- Null guard pattern for optional @export nodes: consistent with existing `if spawn_parent:` guards in `body.gd`

### Integration Points
- `world.gd`: The test enemy instance will be placed here as a child during Phase 4 development; `setup_spawn_parent()` must be called on it
- `Ship._ready()`: Needs the null guard on `picker` (D-01) — affects `ship.gd` directly
- Detection `Area2D` layer/mask: must reference physics layers defined in `world.gd`

</code_context>

<deferred>
## Deferred Ideas

- Fire loop infrastructure in EnemyShip base class — user chose "fire entirely in concrete types"; base class provides barrel node but no Timer or bullet logic
- Flocking / Boids cohesion for Swarmer — deferred to v2.1+
- Predictive targeting for Sniper — deferred to v2.1+
- Pre-wave HUD announcement — deferred to v2.1+

</deferred>

---

*Phase: 04-enemyship-infrastructure*
*Context gathered: 2026-04-11*
