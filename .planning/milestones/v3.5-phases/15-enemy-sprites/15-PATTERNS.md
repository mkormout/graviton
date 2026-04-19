# Phase 15: Enemy Sprites - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 14 (5 enemy ship scripts + 5 enemy ship scenes + 4 bullet scenes)
**Analogs found:** 14 / 14

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `components/beeliner.gd` | script (extend _ready) | event-driven | `components/beeliner.gd` itself (add to existing _ready) | self |
| `components/sniper.gd` | script (extend _ready) | event-driven | `components/beeliner.gd` | exact |
| `components/flanker.gd` | script (extend _ready) | event-driven | `components/beeliner.gd` | exact |
| `components/swarmer.gd` | script (extend _ready) | event-driven | `components/beeliner.gd` | exact |
| `components/suicider.gd` | script (extend _ready) | event-driven | `components/beeliner.gd` | exact |
| `prefabs/enemies/beeliner/beeliner.tscn` | scene | config | `prefabs/ship-bfg-23/ship-bfg-23.tscn` (PointLight2D+GradientTexture2D) | role-match |
| `prefabs/enemies/sniper/sniper.tscn` | scene | config | `prefabs/enemies/beeliner/beeliner.tscn` | exact |
| `prefabs/enemies/flanker/flanker.tscn` | scene | config | `prefabs/enemies/beeliner/beeliner.tscn` | exact |
| `prefabs/enemies/swarmer/swarmer.tscn` | scene | config | `prefabs/enemies/beeliner/beeliner.tscn` | exact |
| `prefabs/enemies/suicider/suicider.tscn` | scene | config | `prefabs/enemies/beeliner/beeliner.tscn` | exact |
| `prefabs/enemies/beeliner/beeliner-bullet.tscn` | scene (bullet) | config | `prefabs/enemies/beeliner/beeliner-bullet.tscn` itself | self |
| `prefabs/enemies/sniper/sniper-bullet.tscn` | scene (bullet) | config | `prefabs/enemies/beeliner/beeliner-bullet.tscn` | exact |
| `prefabs/enemies/flanker/flanker-bullet.tscn` | scene (bullet) | config | `prefabs/enemies/beeliner/beeliner-bullet.tscn` | exact |
| `prefabs/enemies/swarmer/swarmer-bullet.tscn` | scene (bullet) | config | `prefabs/enemies/beeliner/beeliner-bullet.tscn` | exact |

---

## Pattern Assignments

### Enemy GDScripts — `components/beeliner.gd` (and all four others)

**Analog:** `components/beeliner.gd` (existing file, add to it)
**Tween analog:** `components/score-manager.gd` lines 160–164 (create_tween usage)

**Existing _ready() structure to extend** (`components/beeliner.gd` lines 18–22):
```gdscript
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
```

**Pattern: Add @export vars at top of class** (after existing @export vars, before var declarations):
```gdscript
# Sprite configuration — all @export for post-playtest tuning
@export var sprite_region: Rect2 = Rect2(20, 10, 390, 700)   # [ASSUMED: verify in editor]
@export var sprite_scale: Vector2 = Vector2(1.76, 1.76)        # [ASSUMED: 688/390]
@export var gem_energy_min: float = 0.5
@export var gem_energy_max: float = 1.8
@export var gem_pulse_half_period: float = 0.6
```

**Pattern: Extend _ready() with two setup calls** (append after existing super() call chain):
```gdscript
func _ready() -> void:
    super()
    thrust *= randf_range(0.8, 1.2)
    max_speed *= randf_range(0.8, 1.2)
    _fire_timer.timeout.connect(_on_fire_timer_timeout)
    _setup_sprite()       # ADD
    _setup_gem_light()    # ADD
```

**Pattern: _setup_sprite() function** (new private function):
```gdscript
func _setup_sprite() -> void:
    var atlas: Texture2D = load("res://ships_assests.png")
    if atlas == null:
        return  # SPR-03: Polygon2D stays visible as fallback
    var sprite := $Sprite2D as Sprite2D
    sprite.texture = atlas
    sprite.region_enabled = true
    sprite.region_rect = sprite_region
    sprite.rotation_degrees = -90.0   # atlas "up" → Godot +X facing
    sprite.scale = sprite_scale
    $Shape.visible = false
```

**Pattern: _setup_gem_light() + _start_pulse() functions** (new private functions).
Tween pattern sourced from `components/score-manager.gd` lines 160–164:
```gdscript
# score-manager.gd reference (lines 160-164):
#   var tween := node.create_tween()
#   tween.set_parallel(true)
#   tween.tween_property(node, "global_position:y", world_pos.y - 120.0, 1.5)
#   tween.tween_property(label, "modulate:a", 0.0, 1.5)
#   tween.chain().tween_callback(node.queue_free)

func _setup_gem_light() -> void:
    var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
    var light := $GemLight as PointLight2D
    light.enabled = false
    notifier.screen_entered.connect(func(): light.enabled = true)
    notifier.screen_exited.connect(func(): light.enabled = false)
    _start_pulse(light)

func _start_pulse(light: PointLight2D) -> void:
    var tween := create_tween()
    tween.set_loops(0)                # 0 = infinite in Godot 4
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(light, "energy", gem_energy_max, gem_pulse_half_period)
    tween.tween_property(light, "energy", gem_energy_min, gem_pulse_half_period)
```

**Suicider note:** `components/suicider.gd` has no `_fire_timer` — its `_ready()` is simpler (lines 11–20). Same two-function addition applies; no `_fire_timer` line to work around.

---

### Per-Enemy @export Default Values

| Enemy | sprite_region (ASSUMED) | sprite_scale (ASSUMED) | gem_energy_min | gem_energy_max | gem_pulse_half_period |
|-------|------------------------|------------------------|----------------|----------------|-----------------------|
| Beeliner | `Rect2(20, 10, 390, 700)` | `Vector2(1.76, 1.76)` | 0.5 | 1.8 | 0.6 |
| Sniper | `Rect2(440, 10, 380, 780)` | `Vector2(1.81, 1.81)` | 0.2 | 2.5 | 1.5 |
| Flanker | `Rect2(870, 30, 360, 720)` | `Vector2(1.43, 1.43)` | 0.4 | 1.6 | 0.8 |
| Swarmer | `Rect2(1295, 50, 360, 650)` | `Vector2(0.96, 0.96)` | 0.3 | 2.0 | 0.25 |
| Suicider | `Rect2(1720, 80, 340, 640)` | `Vector2(1.01, 1.01)` | 0.6 | 3.0 | 0.15 |

All Rect2 and scale values marked ASSUMED — require editor visual verification.

---

### Enemy Ship Scenes — `prefabs/enemies/beeliner/beeliner.tscn` (and all four others)

**Analog:** `prefabs/ship-bfg-23/ship-bfg-23.tscn` for PointLight2D + GradientTexture2D pattern (lines 25–31, 117–129)

**Existing Sprite2D node in each enemy scene** (already present, configure in place):

In `beeliner.tscn` the `Sprite2D` node is inherited from `base-enemy-ship.tscn` (line 24 of base scene). In the individual enemy tscn files (e.g., `sniper.tscn`), there is no explicit Sprite2D override — the node is inherited. The planner must add an explicit `[node name="Sprite2D" ...]` override line to each enemy .tscn to set texture/region properties.

**Existing Polygon2D "Shape" node** (all five enemy scenes, keep `visible = true` as default — script hides it):

From `beeliner.tscn` lines 57–59:
```
[node name="Shape" type="Polygon2D" parent="."]
color = Color(1, 1, 0, 1)
polygon = PackedVector2Array(250, 0, 125, 216, -125, 216, -250, 0, -125, -216, 125, -216)
```

**Pattern: GradientTexture2D sub_resource** (copy from `ship-bfg-23.tscn` lines 22–32):
```
[sub_resource type="Gradient" id="Gradient_gem_{enemy}"]
colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_gem_{enemy}"]
gradient = SubResource("Gradient_gem_{enemy}")
width = 256
height = 256
use_hdr = true
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.5, 1.0)
```

**Pattern: GemLight PointLight2D node** (modeled after `ship-bfg-23.tscn` lines 117–129, but with `shadow_enabled = false`):
```
[node name="GemLight" type="PointLight2D" parent="."]
position = Vector2(0, 0)        # [ASSUMED: adjust to gem location per sprite]
color = Color(0.0, 0.9, 0.2, 1) # per-enemy gem color (see table below)
energy = 0.5                    # initial energy (gem_energy_min default)
shadow_enabled = false          # CRITICAL: must be false — shadow cost scales with enemy count
texture = SubResource("GradientTexture2D_gem_{enemy}")
texture_scale = 8.0
```

**Pattern: VisibleOnScreenNotifier2D node** (new node, no existing analog — Godot 4 built-in):
```
[node name="VisibleOnScreenNotifier2D" type="VisibleOnScreenNotifier2D" parent="."]
rect = Rect2(-400, -400, 800, 800)  # per-enemy rect (see table below)
```

**Per-Enemy Scene Values:**

| Enemy | GemLight color | VisibilityNotifier rect | GemLight position |
|-------|----------------|-------------------------|-------------------|
| Beeliner | `Color(0.0, 0.9, 0.2, 1)` | `Rect2(-400, -400, 800, 800)` | `Vector2(0, 0)` [ASSUMED] |
| Sniper | `Color(0.6, 0.0, 1.0, 1)` | `Rect2(-400, -400, 800, 800)` | `Vector2(0, 0)` [ASSUMED] |
| Flanker | `Color(1.0, 0.45, 0.0, 1)` | `Rect2(-300, -300, 600, 600)` | `Vector2(0, 0)` [ASSUMED] |
| Swarmer | `Color(1.0, 0.75, 0.0, 1)` | `Rect2(-200, -200, 400, 400)` | `Vector2(0, 0)` [ASSUMED] |
| Suicider | `Color(1.0, 0.05, 0.05, 1)` | `Rect2(-200, -200, 400, 400)` | `Vector2(0, 0)` [ASSUMED] |

GemLight position must be adjusted per sprite after atlas regions are verified in editor.

---

### Enemy Bullet Scenes — `prefabs/enemies/beeliner/beeliner-bullet.tscn` (and three others)

**Analog:** `prefabs/enemies/beeliner/beeliner-bullet.tscn` (the file itself, lines 27–28)

**Existing Sprite2D node** (already present in all four bullet scenes, configure in place):

From `beeliner-bullet.tscn` lines 27–28:
```
[node name="Sprite2D" type="Sprite2D" parent="."]
rotation = 1.5708
```

Same pattern in `sniper-bullet.tscn` lines 27–28, `flanker-bullet.tscn` lines 27–28.

**Pattern: Add atlas texture reference and region to Sprite2D** (override the existing Sprite2D node):

First add an `ext_resource` reference to the atlas at the top of each bullet .tscn:
```
[ext_resource type="Texture2D" path="res://ships_assests.png" id="N_atlas"]
```

Then override the Sprite2D node:
```
[node name="Sprite2D" type="Sprite2D" parent="."]
rotation = 1.5708                          # keep existing rotation
texture = ExtResource("N_atlas")
region_enabled = true
region_rect = Rect2(20, 1060, 120, 280)   # per-bullet region [ASSUMED: verify in editor]
scale = Vector2(0.3, 0.3)                 # [ASSUMED: adjust to match collision shape]
```

**Per-Bullet Region Constants (ASSUMED — verify in editor):**

| Bullet Scene | region_rect |
|--------------|-------------|
| `beeliner-bullet.tscn` | `Rect2(20, 1060, 120, 280)` |
| `sniper-bullet.tscn` | `Rect2(440, 1060, 120, 320)` |
| `flanker-bullet.tscn` | `Rect2(870, 1060, 120, 300)` |
| `swarmer-bullet.tscn` | `Rect2(1295, 1060, 100, 240)` |

---

## Shared Patterns

### Sprite2D Atlas Region Setup
**Source:** RESEARCH.md Pattern 1 (no existing codebase analog — first atlas sprite use)
**Apply to:** All five enemy ship .gd `_setup_sprite()` functions

Key rules:
- Use `load()` not `preload()` — avoids compile-time failure if atlas missing (SPR-03)
- Check return for `null` before configuring sprite
- Set `rotation_degrees = -90.0` on Sprite2D — atlas sprites point up (+Y), Godot facing is +X
- Set `visible = false` on `$Shape` only after successful load (Polygon2D stays visible as fallback)
- Scale only the `Sprite2D` child node, never the parent `RigidBody2D` (collision shapes must stay unchanged)

### Tween Loop Pattern
**Source:** `components/score-manager.gd` lines 160–164 (create_tween, tween_property, chain)
**Apply to:** All five enemy ship `_start_pulse()` functions

Key rules:
- Call `create_tween()` inside `_ready()` only — never in `_init()` (requires scene tree)
- `set_loops(0)` = infinite in Godot 4
- `set_trans(Tween.TRANS_SINE)` gives organic pulse feel
- Two sequential `tween_property` calls (no `.set_parallel()`) produce the ping-pong min→max→min

### PointLight2D Configuration
**Source:** `prefabs/ship-bfg-23/ship-bfg-23.tscn` lines 117–129 (PropellerMainEffectLight)
**Apply to:** All five enemy ship .tscn `GemLight` nodes

Key rule: `shadow_enabled = false` on all gem lights (player ship uses `shadow_enabled = true` for its single main structural light — do NOT copy that; gem lights are decorative and many).

### VisibleOnScreenNotifier2D Signal Wiring
**Source:** No existing codebase analog (first use of this node in project)
**Apply to:** All five enemy ship `_setup_gem_light()` functions

Pattern:
```gdscript
notifier.screen_entered.connect(func(): light.enabled = true)
notifier.screen_exited.connect(func(): light.enabled = false)
```
Start `light.enabled = false` so off-screen enemies that spawn outside viewport don't have active lights until they enter.

### @export Convention for Tunable Values
**Source:** All enemy .gd files (`beeliner.gd` lines 4–6, `sniper.gd` lines 4–11, etc.)
**Apply to:** All five enemy .gd files for sprite_region, sprite_scale, gem_energy_min, gem_energy_max, gem_pulse_half_period

All five values must be `@export` — post-playtest adjustment must work without code changes.

---

## No Analog Found

All files have analogs or self-references. No files lack a pattern source.

---

## Implementation Order Note

The planner should sequence tasks as:

1. Measure atlas regions in Godot sprite region editor (prerequisite — all Rect2 values are ASSUMED)
2. Add _setup_sprite() + _setup_gem_light() to all five .gd files
3. Add GradientTexture2D sub_resources + GemLight + VisibleOnScreenNotifier2D nodes to all five ship .tscn files
4. Configure Sprite2D atlas region in all five ship .tscn files
5. Configure Sprite2D atlas region in all four bullet .tscn files
6. Playtest wave 20, tune @export values

---

## Metadata

**Analog search scope:** `components/`, `prefabs/enemies/`, `prefabs/ship-bfg-23/`
**Files scanned:** 14 source files read directly
**Pattern extraction date:** 2026-04-17
