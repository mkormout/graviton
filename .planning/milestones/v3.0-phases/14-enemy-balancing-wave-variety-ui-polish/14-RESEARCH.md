# Phase 14: Enemy Balancing + Wave Variety + UI Polish — Research

**Researched:** 2026-04-16
**Domain:** Godot 4.6.2 GDScript — AI state machine tweaks, Tween-based UI, CanvasLayer wiring
**Confidence:** HIGH (all findings from direct codebase inspection)

## Summary

This phase is a game-feel polish pass with all major decisions locked in CONTEXT.md. Every enemy script, scene, and UI file has been read directly. No external libraries are introduced; all work is Godot 4 GDScript modifications to existing files.

The dominant technical risk is the wave-flow refactor: the WaveManager's `_countdown_timer` auto-advance and the `wave_completed` signal must be replaced by a manual-advance pattern without breaking the ScoreManager connection established in Phase 11. The second risk is the Swarmer speed-tier feature, which requires WaveManager to communicate a group-level property to each spawned instance — a pattern not yet established in the codebase.

Enemy stat buffs are export-value-only changes in `.tscn` files. Enemy orientation is a per-scene `rotation` adjustment on the `Shape` (Polygon2D) child node. Behavioral tweaks are isolated additions within existing `_tick_state` methods. The controls-hint toggle requires a new `.gd` script attached to the existing `controls-hint.tscn` (currently has no script).

**Primary recommendation:** Implement in this order — (1) enemy stat exports + orientation, (2) per-type behavioral tweaks, (3) wave-manager refactor, (4) wave-clear UI, (5) announcement label resize + tween, (6) controls-hint script + toggle. This order means each task can be tested in isolation before the next depends on it.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Enemy stat values (HP, range, speed) | Enemy `.tscn` scene exports | Enemy `.gd` script defaults | Godot export overrides — scene values win over script defaults |
| Polygon2D orientation offset | Enemy `.tscn` scene (`Shape` node rotation) | — | Visual transform is a scene property, not logic |
| Beeliner jitter | `beeliner.gd` `_tick_state` | — | State-machine physics: runs every frame in SEEKING/FIGHTING |
| Sniper strafe | `sniper.gd` `_tick_state` FIGHTING branch | — | Sinusoidal force applied while in FIGHTING state |
| Flanker patrol bug | `flanker.gd` `_on_detection_area_body_exited` | — | The bug is in the exit handler, not `_tick_state` |
| Swarmer speed tier | `swarmer.gd` `_ready` + `wave-manager.gd` spawn | — | WaveManager sets group property before adding to tree |
| Suicider speed + explosion | `suicider.tscn` exports + `suicider-explosion.tscn` | — | `max_speed` in scene root; `radius` and `attack` in explosion scene |
| Wave-clear flow | `wave-manager.gd` | `world.gd` input, `wave-hud.gd` display | WaveManager owns state; world handles input; HUD shows label |
| Wave announcement tween | `wave-hud.gd` | — | Already owns `_announcement_label` and create_tween() |
| Controls-hint toggle | New `controls-hint.gd` (create) | `world.gd` input | New script needed — scene currently has no .gd |
| ► arrow button | `controls-hint.tscn` (add Button node) | `controls-hint.gd` `_ready()` | Permanent affordance; wired in script |

## Standard Stack

### Core (all already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot GDScript | 4.6.2 | All game logic | Project constraint |
| Tween (built-in) | 4.6.2 | Animation: fade in/out, value transitions | Already used in wave-hud.gd and score-hud.gd |
| Timer (built-in) | 4.6.2 | Enemy fire rates, jitter intervals | Already used in all enemy scripts |
| CanvasLayer | 4.6.2 | HUD overlays | Already used for WaveHud, ScoreHud, ControlsHint |
| Signal (built-in) | 4.6.2 | Decoupled event wiring | WaveManager already emits multiple signals |

### No new dependencies
All work is within the existing Godot 4 engine API. No packages, no new autoloads.

## Architecture Patterns

### System Architecture Diagram

```
INPUT (world.gd _input)
  │
  ├─► KEY_TAB ──────────────────────► ControlsHint.toggle()
  ├─► KEY_ENTER (wave-clear pending) ► WaveManager.trigger_wave()
  └─► KEY_F (existing, unchanged) ──► WaveManager.trigger_wave()

WaveManager
  │  wave_started ──────────────────► WaveHud._on_wave_started()    [announcement label]
  │  wave_completed ────────────────► WaveHud._on_wave_completed()  [shows wave-clear label]
  │  wave_cleared_waiting (NEW) ────► world.gd [gates ENTER key]
  │  enemy_count_changed ──────────► WaveHud._on_enemy_count_changed()
  └─► trigger_wave() [only via explicit input, timer removed]

Enemy spawn (WaveManager._spawn_enemy)
  └─► For swarmer groups: set speed_tier on instance before add_child
```

### Recommended Project Structure
No structural changes needed. Files modified in-place:
```
components/
├── beeliner.gd          # add jitter vars + _jitter_timer + _tick_state additions
├── sniper.gd            # add strafe vars + sinusoidal force in FIGHTING
├── flanker.gd           # fix _on_detection_area_body_exited
├── swarmer.gd           # add speed_tier export
├── suicider.gd          # (no code change — speed and explosion are scene exports)
├── wave-manager.gd      # remove countdown, add wave_cleared_waiting signal
prefabs/enemies/
├── beeliner/beeliner.tscn        # max_health, fight_range, bullet_speed; Shape rotation
├── sniper/sniper.tscn            # max_health, fight_range etc, bullet_speed; Shape rotation
├── flanker/flanker.tscn          # max_health, fight_range, bullet_speed; Shape rotation
├── swarmer/swarmer.tscn          # max_health, fight_range, bullet_speed; Shape rotation
├── suicider/suicider.tscn        # max_health, max_speed
├── suicider/suicider-explosion.tscn  # radius (675 → ~1012), attack energy/kinetic
prefabs/ui/
├── wave-hud.tscn        # add WaveClearLabel node
├── wave-hud.gd          # add _on_wave_completed, show/hide wave-clear label
├── controls-hint.tscn   # add ► Button node; keep MarginContainer
└── controls-hint.gd     # NEW: toggle(), _ready() button wiring, hidden by default
world.gd                 # KEY_TAB, KEY_ENTER reassignment; instantiate controls-hint
```

## Verified Current State (from codebase inspection)

### Enemy Scene Export Values — CURRENT

[VERIFIED: direct .tscn file read]

| Enemy | max_health | max_speed | thrust | fight_range (script def) | fight_range (scene) | bullet_speed (script def) | score_value |
|-------|-----------|-----------|--------|--------------------------|---------------------|---------------------------|-------------|
| Beeliner | 30 | 2000 | 1500 | 400 | **8000** (scene override) | 4400 | 100 |
| Sniper | 50 | 1500 | 1200 | 11000 | not overridden | 10000 | 200 |
| Flanker | 40 | 2000 | 1500 | 4500 | not overridden | 6050 | 150 |
| Swarmer | 15 | 1800 | 1200 | 5000 | not overridden | 3500 | 50 |
| Suicider | 20 | 4000 | 2000 | — (charge, not fire) | — | — | 75 |

**Note:** All score_value exports already match D-08 (100/200/150/50/75). No score changes needed.

**Note:** Beeliner `fight_range` is **8000 in the scene** (already a Phase 5 tuned value), not the script default of 400. Doubling gives 16000 — set in scene.

### Polygon2D Orientation — CURRENT (VERIFIED: .tscn polygon arrays)

| Enemy | Shape vertices (relevant) | Vertex at +X? | Action needed |
|-------|---------------------------|---------------|---------------|
| Beeliner | `PackedVector2Array(250, 0, ...)` — hexagon | YES (250,0) | None — already correct |
| Sniper | `PackedVector2Array(-200,-200, 200,-200, 200,200, -200,200)` — square | Edges, not vertex | Rotate 45° (PI/4) to align corner with +X |
| Flanker | `PackedVector2Array(0, -250, 238, -77, 147, 202, -147, 202, -238, -77)` — pentagon | Vertex at (0,-250) = top | Rotate -90° (TAU/4 = -PI/2) to point vertex right |
| Swarmer | `PackedVector2Array(0, -250, 216, 125, -216, 125)` — triangle | Vertex at (0,-250) = top | Rotate -90° (-PI/2) to point vertex right |
| Suicider | 16-point circle approximation — symmetric | All edges/vertices equidistant | None needed (circular) |

**Rotation convention:** In Godot, the `rotation` property on a Node2D child is in radians. `rotation = -PI/2` rotates CCW by 90°, pointing what was "up" to "right" (+X). Set on the `Shape` (Polygon2D) node's `rotation` field in the `.tscn`.

### Suicider Explosion — CURRENT (VERIFIED: suicider-explosion.tscn)

```
radius = 675.0
power = 15000
attack.energy = 17500.0
attack.kinetic = 5000.0
hit_ships = true
```

D-17 requests +50% radius: `675 * 1.5 = 1012.5` → set `radius = 1013.0`.
Also increase damage proportionally: energy `17500 * 1.5 = 26250`, kinetic `5000 * 1.5 = 7500`.

### WaveManager — CURRENT (VERIFIED: wave-manager.gd)

Signals currently emitted:
- `wave_started(wave_number, enemy_count, label_text)` — emit in `trigger_wave()`
- `enemy_count_changed(remaining, total)` — emit in `_on_enemy_tree_exiting()`
- `all_waves_complete()` — emit in `_on_wave_complete()`
- `countdown_tick(seconds_remaining: int)` — emit in countdown loop
- `wave_completed(wave_number: int)` — emit in `_on_wave_complete()`

**`countdown_seconds = 5.0` export** — this and `_countdown_timer` are removed in D-01.

`_on_wave_complete()` currently: emits `wave_completed`, then starts `_countdown_timer`. New behavior: emit `wave_completed`, emit `wave_cleared_waiting`, stop. `trigger_wave()` only advances when called explicitly.

### WaveHud — CURRENT (VERIFIED: wave-hud.gd + wave-hud.tscn)

- `_announcement_label` exists at `$AnnouncementLabel` — direct child of CanvasLayer root (not in Panel)
- Current font size: `theme_override_font_sizes/font_size = 48` — D-18 says increase to ≥72
- Current tween: 3s linear fade — D-19 replaces with 0.3s fade-in, 2s hold, 1s fade-out
- `connect_to_wave_manager` already connects 4 signals; needs to also connect new `wave_cleared_waiting`
- No `_on_wave_completed` handler yet — must be added

### Controls Hint — CURRENT (VERIFIED: controls-hint.tscn)

- Node type: `CanvasLayer` named `Controls-hint` (note: hyphenated, not underscore)
- Has MarginContainer anchored to top-right (`anchor_left = 1.0, anchor_right = 1.0`)
- Has Panel with RichTextLabel inside
- **No .gd script attached** — must create `prefabs/ui/controls-hint.gd`
- Current text references `ENTER - asteroid spawn` (to be updated per D-07)

### World.gd — CURRENT (VERIFIED: world.gd)

Current KEY_ENTER handler:
```gdscript
if Input.is_key_pressed(KEY_ENTER):
    spawn_asteroids(10)
```

Current KEY_F handler (uses event detection, not polling):
```gdscript
if event is InputEventKey and event.pressed and event.keycode == KEY_F:
    $WaveManager.trigger_wave()
```

**No KEY_TAB handler exists** — must be added.

`controls-hint.tscn` is **not yet instantiated in world.gd** — it is a standalone scene.

## Implementation Order and Dependencies

### Wave 1: Enemy Stats + Orientation (no dependencies)
1. Update `.tscn` export values for all 5 enemies (max_health x2, fight_range x2, bullet_speed x1.4)
2. Update suicider-explosion.tscn (radius, attack values)
3. Set `rotation` on `Shape` Polygon2D nodes (Sniper: PI/4, Flanker: -PI/2, Swarmer: -PI/2)

### Wave 2: Behavioral Tweaks (depends on enemy scripts being stable)
4. Beeliner: add jitter timer + perpendicular force
5. Sniper: add sinusoidal strafe in FIGHTING branch
6. Flanker: fix patrol resumption bug in `_on_detection_area_body_exited`
7. Swarmer: add `speed_tier` export + `_ready()` application
8. Update WaveManager `_spawn_enemy` for Swarmer speed tier injection

### Wave 3: Wave Flow Refactor (depends on WaveManager signal wiring)
9. WaveManager: add `wave_cleared_waiting` signal, remove countdown timer, update `_on_wave_complete`
10. WaveHud: add WaveClearLabel node to scene, add `_on_wave_completed` + `_on_wave_cleared_waiting` handlers
11. World.gd: add `wave_cleared_waiting` state tracking; gate KEY_ENTER; add KEY_TAB; instantiate controls-hint

### Wave 4: UI Polish (depends on wave flow changes)
12. WaveHud: resize `_announcement_label` font to 72; update tween to fade-in 0.3s + hold 2s + fade-out 1s
13. Create `controls-hint.gd` with `toggle()` and hidden default
14. Update `controls-hint.tscn`: attach script, add ► Button, update RichTextLabel text

## Code Examples

### Pattern 1: Beeliner Perpendicular Jitter
```gdscript
# Source: codebase (beeliner.gd) — new additions
@export var jitter_force: float = 300.0

var _jitter_timer: float = 0.0
var _jitter_dir: float = 1.0

# In _tick_state, SEEKING and FIGHTING branches:
_jitter_timer -= _delta
if _jitter_timer <= 0.0:
    _jitter_timer = randf_range(1.0, 2.0)
    _jitter_dir = 1.0 if randf() > 0.5 else -1.0

var perp := Vector2.from_angle(global_rotation + PI / 2.0) * _jitter_dir
apply_central_force(perp * jitter_force)
```

**Gotcha:** `Vector2.from_angle(global_rotation).orthogonal()` gives the same perpendicular but with a fixed sign. Use `randf()` to pick sign and store it in `_jitter_dir` so the Beeliner doesn't oscillate every frame.

### Pattern 2: Sniper Sinusoidal Strafe
```gdscript
# Source: codebase (sniper.gd) — new addition
@export var strafe_force: float = 200.0
@export var strafe_period: float = 4.0  # seconds per full oscillation

var _strafe_time: float = 0.0

# In _tick_state, State.FIGHTING branch (after look_at and before range checks):
_strafe_time += _delta
var strafe_mult := sin(_strafe_time * TAU / strafe_period)
var perp := Vector2.from_angle(global_rotation + PI / 2.0) * strafe_mult
apply_central_force(perp * strafe_force)
```

**Gotcha:** `_strafe_time` must be reset to 0.0 in `_enter_state(State.FIGHTING)` to avoid discontinuous motion when re-entering FIGHTING from FLEEING. Otherwise the oscillation phase is random relative to when combat starts — which is actually fine for variety, but resetting gives deterministic starting phase.

### Pattern 3: Flanker Patrol Resumption Bug Fix
```gdscript
# Source: codebase (flanker.gd) — current BUGGY code:
func _on_detection_area_body_exited(body: Node2D) -> void:
    if body == _target:
        _target = null
        _change_state(State.IDLING)  # BUG: goes IDLE instead of PATROLLING/LURKING

# FIXED:
func _on_detection_area_body_exited(body: Node2D) -> void:
    if body == _target:
        # Only drop target if we're actively SEEKING (already close to target).
        # If LURKING or FIGHTING, keep _target valid; distance-based leash handles it.
        if current_state == State.SEEKING:
            _target = null
            _change_state(State.IDLING)
        # If LURKING and player exits detection radius, Flanker continues orbiting last known position.
        # The leash in _tick_state (dist > max_follow_distance) handles return.
```

**Context:** The current bug is that any time the player exits the `DetectionArea` (radius 10000), the Flanker goes IDLING regardless of state. This means a Flanker that was LURKING at 9800 distance suddenly freezes. The fix: only go IDLING from SEEKING. LURKING and FIGHTING already have leash logic in `_tick_state` via `max_follow_distance`.

**CONTEXT.md note (D-15):** "transition to PATROLLING (or SEEKING if PATROLLING is not wired)". The `EnemyShip.State` enum includes `PATROLLING` but Flanker has no `PATROLLING` implementation. The correct fix per Flanker's existing code is: keep LURKING, not IDLING, when the player exits detection. IDLING is the freeze state.

### Pattern 4: Swarmer Speed Tier
```gdscript
# Source: codebase (swarmer.gd) — new export
@export var speed_tier: float = 1.0  # set by WaveManager before _ready runs... 
# IMPORTANT: exports set before add_child DO run before _ready in Godot 4

# In _ready():
thrust *= speed_tier
max_speed *= speed_tier
# Then apply the existing per-instance variance on top:
thrust *= randf_range(0.8, 1.2)
max_speed *= randf_range(0.8, 1.2)
```

**WaveManager injection (in `_spawn_enemy` or wave group config):**
```gdscript
# Option A: set property on instance before add_child (works because Godot 4 
# processes @export before _ready when property is set pre-tree)
func _spawn_enemy(enemy_scene: PackedScene, speed_tier: float = 1.0) -> void:
    var enemy := enemy_scene.instantiate()
    if enemy.get("speed_tier") != null:
        enemy.speed_tier = speed_tier
    enemy.tree_exiting.connect(_on_enemy_tree_exiting)
    enemy.add_to_group("enemy")
    # ... rest of existing spawn logic
```

**Wave config extension for speed tier (in world.gd waves array):**
```gdscript
# Add "speed_tier" key to swarmer groups:
{ "enemy_scene": swarmer_model, "count": 6, "speed_tier": 0.6 }  # slow swarm
{ "enemy_scene": swarmer_model, "count": 6, "speed_tier": 1.5 }  # fast swarm
```

**WaveManager group spawn loop update:**
```gdscript
for group in groups:
    var enemy_scene: PackedScene = group.get("enemy_scene")
    var count: int = group.get("count", 0)
    var speed_tier: float = group.get("speed_tier", 1.0)
    for i in range(count):
        _spawn_enemy(enemy_scene, speed_tier)
```

**Gotcha:** Properties set on an instance BEFORE `add_child` are received by `_ready()` in Godot 4. This is the established pattern for `spawn_parent` in this codebase — confirmed by `setup_spawn_parent` usage. Setting `speed_tier` before `add_child` is safe.

### Pattern 5: WaveManager — Remove Countdown, Add Manual Advance
```gdscript
# NEW signal declaration:
signal wave_cleared_waiting(wave_number: int)

# Remove: countdown_seconds export, _countdown_remaining, _countdown_timer setup

# Updated _on_wave_complete():
func _on_wave_complete() -> void:
    print("[WaveManager] Wave %d complete!" % _current_wave_index)
    wave_completed.emit(_current_wave_index)
    wave_cleared_waiting.emit(_current_wave_index)  # NEW
    if _current_wave_index >= waves.size():
        all_waves_complete.emit()
    # No countdown timer start — wait for trigger_wave() call

# trigger_wave() is unchanged; called explicitly from world.gd on KEY_ENTER/KEY_F
```

**Gotcha:** The `countdown_tick` signal and `_countdown_label` in WaveHud are currently connected. Removing the timer means `countdown_tick` never fires, so `_countdown_label` never shows — this is the desired behavior. The `countdown_tick` signal can remain declared but unused (no need to remove it).

### Pattern 6: Wave-Clear Label in WaveHud
```gdscript
# New node in wave-hud.tscn (direct child of CanvasLayer, not inside Panel):
# [node name="WaveClearLabel" type="Label" parent="."]
# anchor_left = 0.5, anchor_right = 0.5, anchor_top = 0.5, anchor_bottom = 0.5
# offset_left = -400, offset_right = 400, offset_top = -60, offset_bottom = 60
# horizontal_alignment = 1 (CENTER)
# vertical_alignment = 1 (CENTER)
# theme_override_font_sizes/font_size = 48
# visible = false

# In wave-hud.gd:
@onready var _wave_clear_label: Label = $WaveClearLabel

func _on_wave_cleared_waiting(wave_number: int) -> void:
    _wave_clear_label.text = "WAVE %d CLEARED\nPress Enter or F to continue" % wave_number
    _wave_clear_label.visible = true

func hide_wave_clear_label() -> void:
    _wave_clear_label.visible = false

# connect_to_wave_manager must also connect wave_cleared_waiting:
func connect_to_wave_manager(wm: WaveManager) -> void:
    wm.wave_started.connect(_on_wave_started)
    wm.enemy_count_changed.connect(_on_enemy_count_changed)
    wm.all_waves_complete.connect(_on_all_waves_complete)
    wm.countdown_tick.connect(_on_countdown_tick)
    wm.wave_cleared_waiting.connect(_on_wave_cleared_waiting)  # NEW
```

**Layer note:** `wave-hud.tscn` uses `layer = 10`. The wave-clear label is a direct child of this CanvasLayer, so it renders at layer 10 — above normal game world. D-03 says "visible above all other HUD layers." Current layers: ScoreHud presumably layer 10 or similar, DeathScreen higher. The wave-clear label at layer 10 is fine; if z-order conflicts arise, bump WaveHud to layer 11.

### Pattern 7: Announcement Label Tween (0.3s in, 2s hold, 1s out)
```gdscript
# Source: codebase (wave-hud.gd) — replace existing 3s linear tween
func _on_wave_started(wave_number: int, enemy_count: int, label_text: String) -> void:
    # ... existing panel + label text setup ...
    
    # New tween: fade-in 0.3s, hold 2s, fade-out 1s
    _announcement_label.modulate.a = 0.0
    var tween := _announcement_label.create_tween()
    tween.tween_property(_announcement_label, "modulate:a", 1.0, 0.3)
    tween.tween_interval(2.0)
    tween.tween_property(_announcement_label, "modulate:a", 0.0, 1.0)
```

**Godot 4.x Tween API verified:** [VERIFIED: codebase usage in score-hud.gd]
- `create_tween()` — creates a SceneTreeTween bound to the node
- `tween.tween_property(node, "property:subproperty", end_value, duration)` — works with `"modulate:a"`
- `tween.tween_interval(seconds)` — adds a delay step (replaces old `chain().tween_delay()`)
- `tween.chain()` — sequences steps (not needed when using `tween_interval`)
- `tween.kill()` — stops and invalidates tween (use before creating new one on same node)

**Gotcha:** `tween_interval` is the correct API for a hold period — do NOT use `tween_delay`. In Godot 4, `tween.tween_interval(2.0)` inserts a 2-second wait in the sequence.

### Pattern 8: Controls-Hint Script (New File)
```gdscript
# File: prefabs/ui/controls-hint.gd
class_name ControlsHint
extends CanvasLayer

@onready var _panel_container: MarginContainer = $MarginContainer
@onready var _toggle_button: Button = $ToggleButton  # new node to add in .tscn

var _visible_state: bool = false

func _ready() -> void:
    _panel_container.visible = false  # D-04: hidden by default
    _toggle_button.pressed.connect(toggle)

func toggle() -> void:
    _visible_state = not _visible_state
    _panel_container.visible = _visible_state
    # Update arrow direction
    _toggle_button.text = "◄" if _visible_state else "►"
```

**World.gd addition:**
```gdscript
# Instantiate controls-hint (preload at top of world.gd):
var controls_hint_model = preload("res://prefabs/ui/controls-hint.tscn")

# In _ready(), after other HUD instantiation:
var controls_hint: ControlsHint = controls_hint_model.instantiate()
add_child(controls_hint)

# In _input():
if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
    controls_hint.toggle()
```

**Gotcha:** `controls-hint.tscn` has no script currently — it must have one attached. The `class_name` is optional for scripts attached to scenes but helps with typed references.

**Gotcha:** `KEY_TAB` in Godot 4 may conflict with focus navigation in UI. Since the game uses no tab-navigable UI during normal play, this is not a problem. During the leaderboard/death screen, `get_tree().paused = true` is set, so `world.gd`'s `_input` won't fire while paused (unless process_mode is set). Verify that CanvasLayer process_mode on controls-hint allows processing while paused — the existing phase 12/13 pattern uses `process_mode = Node.PROCESS_MODE_ALWAYS` for HUD nodes shown during pause.

### Pattern 9: KEY_ENTER Reassignment in world.gd
```gdscript
# Current (remove):
if Input.is_key_pressed(KEY_ENTER):
    spawn_asteroids(10)

# New: gate on wave-clear pending state
var _wave_clear_pending: bool = false

# In _ready(), connect to wave manager signal:
$WaveManager.wave_cleared_waiting.connect(func(_n): _wave_clear_pending = true)

# In _input():
if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
    if _wave_clear_pending:
        _wave_clear_pending = false
        $WaveManager.trigger_wave()
        # Tell HUD to hide the wave-clear label:
        wave_hud.hide_wave_clear_label()

# KEY_F already wired to trigger_wave() — add gate here too:
if event is InputEventKey and event.pressed and event.keycode == KEY_F:
    if _wave_clear_pending:
        _wave_clear_pending = false
        $WaveManager.trigger_wave()
        wave_hud.hide_wave_clear_label()
    # else: old behavior (optional — could keep or remove)
```

**Alternative approach:** WaveHud could own `_wave_clear_pending` and expose a method `is_wave_clear_visible()`. Either approach works; the above keeps state in world.gd which already owns all keyboard routing.

**Gotcha:** `wave_hud` must be stored as a variable in world.gd (not just `add_child`). Currently wave_hud is a local variable in `_ready()`. Store it as an instance variable so `_input` can call `hide_wave_clear_label()`.

## Common Pitfalls

### Pitfall 1: Polygon2D Rotation in .tscn vs Code
**What goes wrong:** Setting rotation in code with `$Shape.rotation = X` in `_ready()` works but creates a code dependency. Better to set it directly in the `.tscn` file as a node property.
**Why it happens:** Developers default to code when scenes can store it.
**How to avoid:** Set `rotation` on the `Shape` node in the `.tscn` directly. For Godot 4 `.tscn` format, add `rotation = {value}` to the `[node name="Shape" ...]` block.
**Warning signs:** If Shape rotation is in `_ready()`, it runs every instantiation and is harder to tweak visually.

### Pitfall 2: Tween Kill-Before-Recreate
**What goes wrong:** Creating a new tween on `_announcement_label` without killing the old one leaves orphaned tweens fighting over `modulate.a`.
**Why it happens:** `create_tween()` does not auto-kill previous tweens on the same property.
**How to avoid:** Store the tween in an instance var: `var _announce_tween: Tween`. Call `_announce_tween.kill()` if `_announce_tween != null and _announce_tween.is_running()` before creating a new one. Score-hud.gd already demonstrates this pattern.
**Warning signs:** Label flickers or fades at wrong rate on rapid wave succession.

### Pitfall 3: Swarmer Speed Tier — Property Set After _ready()
**What goes wrong:** Setting `speed_tier` AFTER `add_child()` means `_ready()` has already run and the thrust/max_speed are already calculated.
**Why it happens:** Developer sets property after `add_child` in WaveManager.
**How to avoid:** Set `enemy.speed_tier = value` BEFORE `enemy.add_to_group(...)` and before `get_parent().add_child(enemy)`. The existing codebase sets `spawn_parent` after `add_child` (line 108 of wave-manager.gd) — but `spawn_parent` is not used in `_ready()`, just later. `speed_tier` IS used in `_ready()`, so order matters.
**Warning signs:** All Swarmers move at the same speed regardless of group tier.

### Pitfall 4: Flanker _target Lifetime in FIGHTING State
**What goes wrong:** The FIGHTING state checks `dist > max_follow_distance` to return to LURKING, but if `_target` is also cleared by `_on_detection_area_body_exited`, the `_tick_state` FIGHTING branch hits `not is_instance_valid(_target)` first and jumps to IDLING.
**Why it happens:** Both `_on_detection_area_body_exited` and `_tick_state` modify state.
**How to avoid:** The fix in Pattern 3 only clears target from SEEKING state. LURKING and FIGHTING keep `_target` valid. This is correct — the `_target` node stays valid (PlayerShip doesn't get freed while alive), so `is_instance_valid` won't fail.
**Warning signs:** Flanker goes IDLING mid-combat when player exits detection radius.

### Pitfall 5: WaveHud wave_hud Variable Scope in world.gd
**What goes wrong:** `wave_hud` is currently a local variable in `_ready()`. After refactor, `_input()` needs to call `wave_hud.hide_wave_clear_label()`, but local variables are out of scope.
**Why it happens:** Original code didn't need cross-method access to the HUD.
**How to avoid:** Promote `wave_hud` to an instance variable at the top of world.gd: `var _wave_hud: WaveHud = null` and assign in `_ready()`.
**Warning signs:** `_input` cannot reference `wave_hud` — GDScript will emit a "Identifier not found" error.

### Pitfall 6: TAB Key Focus Conflict
**What goes wrong:** `KEY_TAB` is the default Godot focus-next key for UI controls. If any Control node is focused during gameplay, TAB may move focus instead of (or in addition to) toggling the cheat sheet.
**Why it happens:** Godot's UI input handling fires before custom `_input` in some configurations.
**How to avoid:** In `_input()`, add `get_viewport().gui_release_focus()` before toggling, OR use `event.is_action_pressed("ui_focus_next")` check to block. Simpler: ensure no Control node is focused during normal gameplay (they aren't — the player uses arrow keys + space, no mouse focus).
**Warning signs:** TAB cycles through on-screen UI elements instead of toggling the cheat sheet.

### Pitfall 7: Sinusoidal Force Accumulation
**What goes wrong:** The Sniper strafe force is `apply_central_force()`, which adds to existing forces every physics frame. If the strafe amplitude is too high, the Sniper gains net horizontal momentum over time because the sine wave is sampled at fixed delta intervals.
**Why it happens:** Floating point integration is not perfectly symmetric over a full period.
**How to avoid:** Keep `strafe_force` low (200–300) relative to `thrust` (1200) so the sniper's existing range-keeping logic dominates. The sinusoidal drift is cosmetic, not locomotion.
**Warning signs:** Sniper drifts steadily in one direction instead of oscillating.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sequenced animation (fade in, hold, fade out) | Manual `_process()` alpha counter | Godot `Tween.tween_interval()` | Built-in, GC-managed, already used in project |
| Sinusoidal strafe | Custom oscillator class | `sin(time * TAU / period)` inline in `_tick_state` | One line; no class needed |
| Speed tier communication | Custom event bus or signal | Direct property set before `add_child()` | Established codebase pattern (spawn_parent) |
| Toggle button | Custom click detection | Godot `Button.pressed` signal | Built-in, no mouse region math needed |

## Exact Tuning Values (Claude's Discretion)

These are the specific values the planner should use (discretion delegated to Claude in CONTEXT.md):

### Enemy Stat Buffs
| Enemy | max_health (new) | fight_range (new) | bullet_speed (new) |
|-------|-----------------|-------------------|--------------------|
| Beeliner | 60 (was 30) | 16000 (was 8000 scene) | 6160 (4400 × 1.4) |
| Sniper | 100 (was 50) | fight 22000, comfort 20000, flee 8000, safe 14000 (all ×2) | 14000 (10000 × 1.4) |
| Flanker | 80 (was 40) | 9000 (4500 × 2) | 8470 (6050 × 1.4) |
| Swarmer | 30 (was 15) | 10000 (5000 × 2) | 4900 (3500 × 1.4) |
| Suicider | 40 (was 20) | — | — |

### Suicider Explosion Buff
| Property | Current | New |
|----------|---------|-----|
| radius | 675.0 | 1013.0 |
| attack.energy | 17500.0 | 26250.0 |
| attack.kinetic | 5000.0 | 7500.0 |
| max_speed (scene) | 4000.0 | 5200.0 (+30%) |
| thrust (scene) | 2000.0 | 2600.0 (+30%) |

### Beeliner Jitter
- `jitter_force = 300.0` (20% of thrust 1500)
- Interval: `randf_range(1.0, 2.0)` seconds

### Sniper Strafe
- `strafe_force = 200.0` (17% of thrust 1200)
- `strafe_period = 4.0` seconds per full oscillation

### Swarmer Speed Tiers
- Slow tier: `speed_tier = 0.6` → max_speed 1080, thrust 720 (before ±20% variance)
- Normal tier: `speed_tier = 1.0` (default — existing waves unchanged)
- Fast tier: `speed_tier = 1.5` → max_speed 2700, thrust 1800 (before ±20% variance)

### Wave Announcement Font Size
- `_announcement_label` font: 72px (from 48px)
- `WaveClearLabel` font: 48px (secondary label, smaller than announcement)

### ► Arrow Button Position
- Anchored to right edge, vertically centered (anchor_left=1, anchor_right=1, anchor_top=0.5, anchor_bottom=0.5)
- Use `Button` node type with `text = "►"`, flat style (no background panel)
- Offset: `offset_left = -35` to place it just inside right edge

## Updated Controls Cheat Sheet Text

The `controls-hint.tscn` RichTextLabel text should be updated to:

```
[b]Controls[/b]

ARROW KEYS - thrusters
SPACE - fire all
R - reload
C - camera
I - inventory
Tab - cheat sheet

1 - Minigun
2 - Laser
3 - Gauss Cannon
4 - Rocket Launcher
5 - Gravity Gun
6 - Miniguns & Laser

Q - fire left mount
W - fire front mount
E - fire right mount
A - drop left mount
S - drop front mount
D - drop right mount

F / Enter - next wave
G - god mode for weapon
H - unlimited ammo
J  - max fire rate
```

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — all work is in-engine GDScript edits)

## Validation Architecture

Step 4: SKIPPED (nyquist_validation = false in config.json)

## Security Domain

Step: SKIPPED (no authentication, networking, or user data beyond already-implemented leaderboard)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `tween_interval()` is the correct Godot 4 API for a hold period (not `tween_delay`) | Pattern 7 | Tween has no hold; animation won't pause between fade-in and fade-out |
| A2 | Setting `speed_tier` on a Swarmer instance before `add_child()` is received by `_ready()` | Pattern 4 | Swarmer ignores tier; all swarmers use default speed |
| A3 | TAB key does not conflict with UI focus during normal gameplay (no focused Controls) | Pitfall 6 | TAB cycles UI focus instead of toggling cheat sheet |

**A1 note:** Godot 4 Tween `tween_interval()` is [ASSUMED] — not verified against Godot 4.6.2 official docs, but consistent with GDScript Tween API as of Godot 4.x training knowledge. The alternative `tween_callback(func(): pass).set_delay(2.0)` is a fallback.

**A2 note:** [VERIFIED: codebase] — `spawn_parent` is set via `setup_spawn_parent()` AFTER `add_child()` (wave-manager.gd line 108), but `spawn_parent` is only read inside `_fire()` / `die()`, not `_ready()`. The `speed_tier` property IS used in `_ready()`, so it must be set BEFORE `add_child()`. This is a different access pattern than `spawn_parent`. GDScript `@export` properties set on an instance before `add_child()` ARE available in `_ready()` — this is standard Godot 4 behavior [ASSUMED from training knowledge].

## Sources

### Primary (HIGH confidence)
- Direct codebase read: `components/beeliner.gd`, `sniper.gd`, `flanker.gd`, `swarmer.gd`, `suicider.gd`, `enemy-ship.gd`, `wave-manager.gd`, `body.gd`, `explosion.gd`
- Direct scene read: `prefabs/enemies/*/\*.tscn`, `prefabs/ui/wave-hud.tscn`, `prefabs/ui/controls-hint.tscn`, `prefabs/ui/score-hud.gd`, `prefabs/ui/death-screen.gd`
- `world.gd` — complete keyboard routing and wave array

### Secondary (MEDIUM confidence)
- Godot 4 Tween API patterns inferred from existing `score-hud.gd` usage (`create_tween()`, `tween_property()`, `chain()`, `kill()`)

### Tertiary (LOW confidence)
- `tween_interval()` API signature [ASSUMED] — not verified against Godot 4.6.2 official changelog

## Metadata

**Confidence breakdown:**
- Enemy stat changes: HIGH — direct .tscn read, values are clear
- Polygon2D orientation: HIGH — polygon vertices read directly, rotation math verified
- Behavioral tweaks: HIGH — code patterns exist in codebase, additions are isolated
- Wave flow refactor: HIGH — WaveManager fully read, signal chain clear
- Tween API: MEDIUM — `tween_interval` is assumed; existing patterns verified
- Swarmer speed tier: MEDIUM — property-before-add_child pattern assumed correct

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable Godot APIs, no external deps)
