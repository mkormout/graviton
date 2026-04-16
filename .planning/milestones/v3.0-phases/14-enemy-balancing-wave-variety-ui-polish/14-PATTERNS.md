# Phase 14: Enemy Balancing + Wave Variety + UI Polish - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 11 new/modified files
**Analogs found:** 11 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `components/beeliner.gd` | AI state machine | event-driven | `components/sniper.gd` | exact (same base, sinusoidal force pattern) |
| `components/sniper.gd` | AI state machine | event-driven | `components/flanker.gd` | exact (same base, per-state force) |
| `components/flanker.gd` | AI state machine | event-driven | `components/sniper.gd` | exact (shared detection-area-body-exited fix) |
| `components/swarmer.gd` | AI state machine | event-driven | `components/beeliner.gd` | exact (same `_ready()` variance pattern) |
| `components/wave-manager.gd` | service / orchestrator | event-driven | self (modify in place) | self |
| `prefabs/enemies/*/\*.tscn` (5 scenes) | config | — | `prefabs/enemies/beeliner/beeliner.tscn` | exact |
| `prefabs/enemies/suicider/suicider-explosion.tscn` | config | — | `prefabs/enemies/suicider/suicider-explosion.tscn` | self |
| `prefabs/ui/wave-hud.gd` | UI controller | request-response | `prefabs/ui/score-hud.gd` | role-match (tween pattern, connect_to_X init) |
| `prefabs/ui/wave-hud.tscn` | UI config | — | `prefabs/ui/wave-hud.tscn` | self |
| `prefabs/ui/controls-hint.gd` (NEW) | UI controller | event-driven | `prefabs/ui/death-screen.gd` | role-match (CanvasLayer, Button.pressed wiring) |
| `prefabs/ui/controls-hint.tscn` | UI config | — | `prefabs/ui/wave-hud.tscn` | role-match |
| `world.gd` | entry point / router | event-driven | self (modify in place) | self |

---

## Pattern Assignments

### `components/beeliner.gd` (AI state machine — add jitter)

**Analog:** `components/sniper.gd` (lines 63–82 — sinusoidal force in `_tick_state`)

**Existing `_ready()` variance pattern** (`beeliner.gd` lines 15–19):
```gdscript
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
```
New jitter vars go at top of class, after existing `@export` block. Follow same declaration order as Sniper (`const` → `var` → `@onready`).

**Existing `_tick_state` structure to extend** (`beeliner.gd` lines 21–32):
```gdscript
func _tick_state(_delta: float) -> void:
    match current_state:
        State.SEEKING:
            if _target:
                look_at(_target.global_position)
                steer_toward(_target.global_position)
                if global_position.distance_to(_target.global_position) <= fight_range:
                    _change_state(State.FIGHTING)
        State.FIGHTING:
            if _target:
                look_at(_target.global_position)
                steer_toward(_target.global_position)
```
Add jitter timer decrement + perpendicular force at the **end** of both SEEKING and FIGHTING branches (after the existing `look_at` + `steer_toward` calls).

**Force application pattern** (`sniper.gd` lines 70–73 — perpendicular force in `_tick_state`):
```gdscript
apply_central_force(away * thrust * FIGHTING_THRUST_MULT)
```
Adapt for jitter: `apply_central_force(perp * jitter_force)` where `perp = Vector2.from_angle(global_rotation + PI / 2.0) * _jitter_dir`.

**New exports to add** (follow `@export` pattern at top, before non-exported vars):
```gdscript
@export var jitter_force: float = 300.0
```

**New vars to add** (after `@export` block, before `@onready`):
```gdscript
var _jitter_timer: float = 0.0
var _jitter_dir: float = 1.0
```

---

### `components/sniper.gd` (AI state machine — add sinusoidal strafe in FIGHTING)

**Analog:** `components/flanker.gd` (lines 95–107 — FIGHTING branch with state-local timers)

**Existing `_tick_state` FIGHTING branch** (`sniper.gd` lines 63–74):
```gdscript
        State.FIGHTING:
            look_at(_target.global_position)
            if dist < flee_range:
                _change_state(State.FLEEING)
            elif dist < comfort_range:
                apply_central_force(away * thrust * FIGHTING_THRUST_MULT)
            else:
                apply_central_force(toward * thrust * FIGHTING_THRUST_MULT)
```
Insert `_strafe_time += _delta` and `apply_central_force(perp * strafe_force)` **before** the range-check block. The strafe force is additive — it does not replace the existing range-keeping logic.

**New exports to add** (lines 1–9, after existing exports, same pattern):
```gdscript
@export var strafe_force: float = 200.0
@export var strafe_period: float = 4.0
```

**New var to add** (after existing vars block):
```gdscript
var _strafe_time: float = 0.0
```

**`_enter_state` pattern to copy** (`sniper.gd` lines 83–91 — reset timer on state entry):
```gdscript
func _enter_state(new_state: State) -> void:
    print("[Sniper] _enter_state: %s" % State.keys()[new_state])
    if new_state == State.FIGHTING:
        assert(aim_up_time < _fire_timer.wait_time, ...)
        _fire_timer.start()
    elif new_state == State.FLEEING:
        _fire_timer.stop()
        _aim_timer.stop()
```
Add `_strafe_time = 0.0` inside the `if new_state == State.FIGHTING:` branch.

---

### `components/flanker.gd` (AI state machine — fix patrol resumption bug)

**Analog:** `components/sniper.gd` lines 36–41 — the correct `_on_detection_area_body_exited` pattern already used by Sniper:
```gdscript
func _on_detection_area_body_exited(body: Node2D) -> void:
    # Only reset in SEEKING — FLEEING/FIGHTING have their own range-based exit logic.
    if body == _target and current_state == State.SEEKING:
        _target = null
        _change_state(State.IDLING)
```

**Current buggy code** (`flanker.gd` lines 46–49):
```gdscript
func _on_detection_area_body_exited(body: Node2D) -> void:
    if body == _target:
        _target = null
        _change_state(State.IDLING)
```

**Fix:** Gate on `current_state == State.SEEKING` before clearing target, mirroring Sniper's pattern exactly. LURKING and FIGHTING states have leash logic in `_tick_state` (line 105: `if _fight_remaining <= 0.0 or dist > max_follow_distance`) that handles return without needing to clear the target.

No other changes to `flanker.gd` for the bug fix (stat buffs are `.tscn` export overrides only).

---

### `components/swarmer.gd` (AI state machine — add speed_tier export)

**Analog:** `components/beeliner.gd` lines 15–19 — `_ready()` variance pattern (the pattern to extend):
```gdscript
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
```

**New export to add** (top of file, with existing exports, lines 1–9):
```gdscript
@export var speed_tier: float = 1.0
```

**`_ready()` extension** (`swarmer.gd` lines 22–32): Apply `speed_tier` multiplier BEFORE the existing `randf_range` variance. This is the critical ordering — tier scales the base, then instance variance jitters on top:
```gdscript
func _ready() -> void:
    super()
    thrust *= speed_tier           # tier applied first
    max_speed *= speed_tier        # tier applied first
    thrust *= randf_range(0.8, 1.2)    # existing variance on top
    max_speed *= randf_range(0.8, 1.2) # existing variance on top
    # ... rest unchanged
```

**Property-before-add_child pattern** (from `wave-manager.gd` lines 94–114 — `_spawn_enemy` method). The existing code sets `spawn_parent` via `setup_spawn_parent()` AFTER `add_child` — but `speed_tier` is used in `_ready()` so it must be set BEFORE `add_child`. The pattern to follow is the `instantiate()` → set properties → `add_child` sequence:
```gdscript
func _spawn_enemy(enemy_scene: PackedScene) -> void:
    var enemy := enemy_scene.instantiate()
    # Connect before add_child (existing pattern, line 99)
    enemy.tree_exiting.connect(_on_enemy_tree_exiting)
    enemy.add_to_group("enemy")
    # ...
    get_parent().add_child(enemy)
```
New pattern: insert `if enemy.get("speed_tier") != null: enemy.speed_tier = speed_tier_param` BEFORE `add_to_group` and BEFORE `get_parent().add_child(enemy)`.

---

### `components/wave-manager.gd` (service — remove countdown, add manual advance)

**Analog:** self. No external analog — modify in place.

**Signals block** (`wave-manager.gd` lines 4–8) — add new signal after existing ones:
```gdscript
signal wave_started(wave_number: int, enemy_count: int, label_text: String)
signal enemy_count_changed(remaining: int, total: int)
signal all_waves_complete()
signal countdown_tick(seconds_remaining: int)
signal wave_completed(wave_number: int)
# ADD:
signal wave_cleared_waiting(wave_number: int)
```

**`_on_wave_complete()` current** (`wave-manager.gd` lines 134–150):
```gdscript
func _on_wave_complete() -> void:
    print("[WaveManager] Wave %d complete!" % (_current_wave_index))
    wave_completed.emit(_current_wave_index)
    if _current_wave_index >= waves.size():
        all_waves_complete.emit()
    else:
        # Start countdown to next wave
        _countdown_remaining = int(countdown_seconds)
        countdown_tick.emit(_countdown_remaining)
        _countdown_timer.start()
```
Replace `else` branch: emit `wave_cleared_waiting`, do nothing else. `trigger_wave()` is unchanged — it's already safe to call explicitly.

**Vars/exports to remove:** `countdown_seconds` export (line 16), `_countdown_remaining` (line 21), `_countdown_timer` (line 22). Remove `_countdown_timer` setup in `_ready()` (lines 25–30) and `_on_countdown_tick()` method (lines 145–150).

**`_spawn_enemy` signature change** (line 94): Extend to accept optional `speed_tier: float = 1.0` parameter, set on instance before `add_child`.

**Wave group loop in `trigger_wave()`** (`wave-manager.gd` lines 85–92):
```gdscript
for group in groups:
    var enemy_scene: PackedScene = group.get("enemy_scene")
    var count: int = group.get("count", 0)
    # ...
    for i in range(count):
        _spawn_enemy(enemy_scene)
```
Add `var speed_tier: float = group.get("speed_tier", 1.0)` and pass it to `_spawn_enemy`.

---

### `prefabs/enemies/*.tscn` (5 enemy scenes — stat export overrides)

**Analog:** `prefabs/enemies/beeliner/beeliner.tscn` — the pattern for how exports are overridden in the scene root node block.

**Scene root node export pattern** (`beeliner.tscn` lines 39–51):
```
[node name="Beeliner" type="RigidBody2D" node_paths=PackedStringArray("item_dropper")]
...
script = ExtResource("1_beeliner")
max_health = 30
detection_radius = 10000.0
max_speed = 2000.0
thrust = 1500.0
score_value = 100
fight_range = 8000.0
```
Each stat override is a line in the `[node name="..."]` block. Change the numeric values directly. The `.tscn` format does not require any structural change — only value updates.

**Target values** (per RESEARCH.md tuning table):
| Scene | max_health | fight_range | bullet_speed | Other |
|-------|-----------|-------------|-------------|-------|
| `beeliner.tscn` | 60 | 16000 | 6160 | — |
| `sniper.tscn` | 100 | 22000 (fight), 20000 (comfort), 8000 (flee), 14000 (safe) | 14000 | — |
| `flanker.tscn` | 80 | 9000 | 8470 | — |
| `swarmer.tscn` | 30 | 10000 | 4900 | — |
| `suicider.tscn` | 40 | — | — | max_speed=5200, thrust=2600 |

**Polygon2D rotation pattern** (`beeliner.tscn` lines 56–58 — Shape node):
```
[node name="Shape" type="Polygon2D" parent="."]
color = Color(1, 1, 0, 1)
polygon = PackedVector2Array(250, 0, ...)
```
For scenes needing rotation: add `rotation = {value}` line to the `[node name="Shape" ...]` block in the `.tscn` file. Target values: Sniper Shape `rotation = 0.785398` (PI/4), Flanker Shape `rotation = -1.5708` (-PI/2), Swarmer Shape `rotation = -1.5708` (-PI/2). Beeliner and Suicider need no rotation change.

---

### `prefabs/enemies/suicider/suicider-explosion.tscn` (config — explosion radius + damage buff)

**Analog:** self. No external analog.

**Current root node values** (`suicider-explosion.tscn` lines 38–45):
```
[node name="Suicider-explosion" type="Node2D" ...]
script = ExtResource("1_expl")
radius = 675.0
...
power = 15000
attack = SubResource("Resource_dmg1")
```

**`[sub_resource type="Resource" id="Resource_dmg1"]`** (lines 11–13):
```
script = ExtResource("2_dmg")
energy = 17500.0
kinetic = 5000.0
```

Update: `radius = 1013.0`, `energy = 26250.0`, `kinetic = 7500.0`. No structural changes.

---

### `prefabs/ui/wave-hud.gd` (UI controller — add wave-clear label + connect new signal + tween fix)

**Analog:** `prefabs/ui/score-hud.gd` — the tween kill-before-recreate pattern and `connect_to_X` init.

**Tween kill-before-recreate pattern** (`score-hud.gd` lines 13, 58–64):
```gdscript
var _score_tween: Tween = null

func _animate_score_flash() -> void:
    if _score_tween and _score_tween.is_running():
        _score_tween.kill()
    _score_value.add_theme_color_override(...)
    _score_tween = _score_value.create_tween()
    _score_tween.tween_property(...)
    _score_tween.chain().tween_property(...)
```
Apply same pattern to `_announcement_label`: add `var _announce_tween: Tween = null`, kill before creating new one in `_on_wave_started`.

**New tween sequence** (replace `wave-hud.gd` lines 30–31):
```gdscript
# OLD (3s linear fade):
_announcement_label.modulate.a = 1.0
var tween := _announcement_label.create_tween()
tween.tween_property(_announcement_label, "modulate:a", 0.0, 3.0)

# NEW (0.3s fade-in, 2s hold, 1s fade-out):
if _announce_tween and _announce_tween.is_running():
    _announce_tween.kill()
_announcement_label.modulate.a = 0.0
_announce_tween = _announcement_label.create_tween()
_announce_tween.tween_property(_announcement_label, "modulate:a", 1.0, 0.3)
_announce_tween.tween_interval(2.0)
_announce_tween.tween_property(_announcement_label, "modulate:a", 0.0, 1.0)
```

**`connect_to_wave_manager` pattern** (`wave-hud.gd` lines 15–19):
```gdscript
func connect_to_wave_manager(wm: WaveManager) -> void:
    wm.wave_started.connect(_on_wave_started)
    wm.enemy_count_changed.connect(_on_enemy_count_changed)
    wm.all_waves_complete.connect(_on_all_waves_complete)
    wm.countdown_tick.connect(_on_countdown_tick)
```
Add `wm.wave_cleared_waiting.connect(_on_wave_cleared_waiting)` as the fifth line.

**New `@onready` to add** (following `wave-hud.gd` lines 4–8 pattern):
```gdscript
@onready var _wave_clear_label: Label = $WaveClearLabel
```

**New handler methods to add** (follow existing handler naming: `_on_{signal_name}`):
```gdscript
func _on_wave_cleared_waiting(wave_number: int) -> void:
    _wave_clear_label.text = "WAVE %d CLEARED\nPress Enter or F to continue" % wave_number
    _wave_clear_label.visible = true

func hide_wave_clear_label() -> void:
    _wave_clear_label.visible = false
```

---

### `prefabs/ui/wave-hud.tscn` (UI scene — add WaveClearLabel node)

**Analog:** `prefabs/ui/wave-hud.tscn` lines 48–63 — `AnnouncementLabel` node as the structural template.

**Existing AnnouncementLabel node** (`wave-hud.tscn` lines 48–63):
```
[node name="AnnouncementLabel" type="Label" parent="."]
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = -400.0
offset_right = 400.0
offset_top = -60.0
offset_bottom = 60.0
grow_horizontal = 2
grow_vertical = 2
modulate = Color(1, 1, 1, 0)
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3
theme_override_font_sizes/font_size = 48
text = ""
```

**New WaveClearLabel node** — add as a sibling of AnnouncementLabel (direct child of CanvasLayer root, not inside Panel). Follow identical anchor/offset pattern, different font size, `visible = false` instead of `modulate` alpha trick:
```
[node name="WaveClearLabel" type="Label" parent="."]
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = -400.0
offset_right = 400.0
offset_top = -60.0
offset_bottom = 60.0
grow_horizontal = 2
grow_vertical = 2
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3
theme_override_font_sizes/font_size = 48
visible = false
text = ""
```

Also update `AnnouncementLabel` font size in place: change `theme_override_font_sizes/font_size = 48` to `= 72`.

---

### `prefabs/ui/controls-hint.gd` (NEW — CanvasLayer script with toggle)

**Analog:** `prefabs/ui/death-screen.gd` — CanvasLayer with Button.pressed wiring in `_ready()`, `visible = false` default, public API method.

**CanvasLayer + visible default pattern** (`death-screen.gd` lines 22–25):
```gdscript
func _ready() -> void:
    _name_input.text_submitted.connect(_on_submit)
    _submit_button.pressed.connect(_on_submit.bind(""))
    visible = false
```

**`@onready` node reference pattern** (`death-screen.gd` lines 14–19):
```gdscript
@onready var _name_section: Control = $NameSection
@onready var _submit_button: Button = $NameSection/VBox/SubmitButton
```

**New file structure** — follow project conventions (class_name + extends on one line, `@export` first, then vars, then `@onready`):
```gdscript
class_name ControlsHint
extends CanvasLayer

@onready var _panel_container: MarginContainer = $MarginContainer
@onready var _toggle_button: Button = $ToggleButton

var _visible_state: bool = false

func _ready() -> void:
    _panel_container.visible = false   # D-04: hidden by default
    _toggle_button.pressed.connect(toggle)

func toggle() -> void:
    _visible_state = not _visible_state
    _panel_container.visible = _visible_state
    _toggle_button.text = "◄" if _visible_state else "►"
```

**No `_input()` in this script** — world.gd owns keyboard routing (TAB key). The Button handles mouse-click toggling only.

---

### `prefabs/ui/controls-hint.tscn` (UI scene — attach script, add ToggleButton, update text)

**Analog:** `prefabs/ui/wave-hud.tscn` — CanvasLayer scene structure with direct-child nodes.

**Existing scene structure** (`controls-hint.tscn` lines 1–61):
```
[node name="Controls-hint" type="CanvasLayer"]
  └── MarginContainer (anchor to top-right)
       └── Panel
            └── RichTextLabel (bbcode_enabled, text = "...")
```

Changes needed:
1. Add `script = ExtResource(...)` reference to the CanvasLayer root node (point to `controls-hint.gd`).
2. Add `ToggleButton` as a **sibling** of MarginContainer (direct child of CanvasLayer root):
```
[node name="ToggleButton" type="Button" parent="."]
anchor_left = 1.0
anchor_right = 1.0
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = -35.0
offset_right = 0.0
offset_top = -20.0
offset_bottom = 20.0
grow_horizontal = 0
grow_vertical = 2
flat = true
text = "►"
```
3. Update `RichTextLabel` `text` property to the v3.0 cheat sheet (see RESEARCH.md section "Updated Controls Cheat Sheet Text").

---

### `world.gd` (entry point — KEY_ENTER reassignment, KEY_TAB, wave state, controls-hint instantiation)

**Analog:** self. Pattern for keyboard routing is established in `world.gd` lines 257–327.

**Key distinction — polling vs event** (`world.gd` lines 288–326):
```gdscript
# Polled keys (fire every frame while held):
if Input.is_key_pressed(KEY_ENTER):
    spawn_asteroids(10)

# Event keys (fire once per keypress):
if event is InputEventKey and event.pressed and event.keycode == KEY_F:
    $WaveManager.trigger_wave()
```
Both KEY_ENTER and KEY_TAB must use the **event** pattern (one-shot, not polling). Reassign KEY_ENTER from `Input.is_key_pressed` polling to `event is InputEventKey and event.pressed`.

**`preload` pattern** (`world.gd` lines 1–18):
```gdscript
var wave_hud_model = preload("res://prefabs/ui/wave-hud.tscn")
var score_hud_model = preload("res://prefabs/ui/score-hud.tscn")
```
Add: `var controls_hint_model = preload("res://prefabs/ui/controls-hint.tscn")`

**Instantiation + connect_to pattern** (`world.gd` lines 57–59):
```gdscript
var wave_hud: WaveHud = wave_hud_model.instantiate()
add_child(wave_hud)
wave_hud.connect_to_wave_manager($WaveManager)
```
Follow same pattern for controls-hint. Also promote `wave_hud` from local var to instance var (see Shared Patterns below).

**Signal connect pattern** (`world.gd` lines 62–63 — ScoreManager connect):
```gdscript
if ScoreManager:
    ScoreManager.connect_to_wave_manager($WaveManager)
```
Add: `$WaveManager.wave_cleared_waiting.connect(func(_n): _wave_clear_pending = true)` in `_ready()`.

**New instance vars to add** at top of `world.gd` (after existing `var godmode`, `var camera_follow`, `var death_screen`):
```gdscript
var _wave_clear_pending: bool = false
var _wave_hud: WaveHud = null
var _controls_hint: ControlsHint = null
```

**Wave array Swarmer group extension** (`world.gd` lines 103–105 — existing swarmer group):
```gdscript
{ "enemy_scene": swarmer_model, "count": 6 }
```
Add `"speed_tier"` key to swarmer groups in waves that should use slow/fast tiers:
```gdscript
{ "enemy_scene": swarmer_model, "count": 6, "speed_tier": 0.6 }   # slow swarm
{ "enemy_scene": swarmer_model, "count": 6, "speed_tier": 1.5 }   # fast swarm
```
Groups without a `speed_tier` key default to `1.0` via `group.get("speed_tier", 1.0)` in WaveManager.

---

## Shared Patterns

### Per-instance Variance in `_ready()`
**Source:** All enemy scripts (`beeliner.gd` lines 16–18, `sniper.gd` lines 22–24, etc.)
**Apply to:** Any new numeric tuning variable that should have per-instance variety
```gdscript
thrust *= randf_range(0.8, 1.2)
max_speed *= randf_range(0.8, 1.2)
```
Rule: Apply tier/group multiplier FIRST, then `randf_range` variance on top.

### Tween Kill Before Recreate
**Source:** `prefabs/ui/score-hud.gd` lines 58–64
**Apply to:** `wave-hud.gd` `_on_wave_started` (announcement label tween)
```gdscript
if _score_tween and _score_tween.is_running():
    _score_tween.kill()
_score_tween = _score_value.create_tween()
_score_tween.tween_property(...)
_score_tween.chain().tween_property(...)
```

### `connect_to_X` Init Method
**Source:** `prefabs/ui/wave-hud.gd` lines 15–19, `prefabs/ui/score-hud.gd` lines 26–30
**Apply to:** Any new UI CanvasLayer that wires to a manager
```gdscript
func connect_to_wave_manager(wm: WaveManager) -> void:
    wm.signal_name.connect(_on_signal_name)
```

### Event-Based Key Handling (one-shot)
**Source:** `world.gd` lines 322–326
**Apply to:** KEY_ENTER reassignment, KEY_TAB addition
```gdscript
if event is InputEventKey and event.pressed and event.keycode == KEY_F:
    $WaveManager.trigger_wave()
```

### Button.pressed Signal Wiring
**Source:** `prefabs/ui/death-screen.gd` lines 23–24
**Apply to:** `controls-hint.gd` ToggleButton wiring
```gdscript
_submit_button.pressed.connect(_on_submit.bind(""))
# Adapt:
_toggle_button.pressed.connect(toggle)
```

### CanvasLayer Hidden by Default
**Source:** `prefabs/ui/death-screen.gd` line 25 (`visible = false`)
**Apply to:** `controls-hint.gd` `_ready()` (hides MarginContainer, not the whole layer — the ToggleButton must remain visible)
```gdscript
_panel_container.visible = false   # only the panel hides; button stays visible
```

### `wave_hud` Scope Promotion
**Source:** `world.gd` lines 57–59 (currently a local var in `_ready()`)
**Apply to:** `world.gd` — promote to instance var so `_input()` can call `_wave_hud.hide_wave_clear_label()`
```gdscript
# At class level (after existing instance vars):
var _wave_hud: WaveHud = null

# In _ready():
_wave_hud = wave_hud_model.instantiate()
add_child(_wave_hud)
_wave_hud.connect_to_wave_manager($WaveManager)
```

---

## No Analog Found

All files in this phase have direct analogs or are self-modifications. No file requires external reference patterns.

| File | Role | Note |
|------|------|-------|
| `prefabs/ui/controls-hint.gd` | UI controller | NEW file — uses death-screen.gd as role-match analog (CanvasLayer + Button.pressed). Closest analog in codebase. |

---

## Metadata

**Analog search scope:** `components/`, `prefabs/ui/`, `prefabs/enemies/`, `world.gd`
**Files scanned:** 13 source files read directly
**Pattern extraction date:** 2026-04-16
