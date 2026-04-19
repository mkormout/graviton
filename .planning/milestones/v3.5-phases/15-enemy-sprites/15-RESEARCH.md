# Phase 15: Enemy Sprites - Research

**Researched:** 2026-04-17
**Domain:** Godot 4 Sprite2D atlas regions, PointLight2D, Tween pulse animation, VisibleOnScreenNotifier2D culling
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Phase 15 includes BOTH ship sprite replacement AND enemy bullet sprite updates in one pass.
- **D-02:** The four firing enemy types (Beeliner, Sniper, Flanker, Swarmer) each have an existing bullet scene that gets a matching sprite from the atlas bottom half. Suicider has no bullet scene — no update needed.
- **D-03:** ENM-07 → Beeliner, ENM-08 → Sniper, ENM-09 → Flanker, ENM-10 → Swarmer, ENM-11 → Suicider.
- **D-04:** PointLight2D gem colors: Beeliner=green, Sniper=purple, Flanker=orange, Swarmer=yellow/amber, Suicider=red.
- **D-05:** Pulse is per-enemy, tuned to behavioral personality (Beeliner steady, Sniper slow hypnotic, Flanker mid-tempo, Swarmer quick flicker, Suicider frantic fast).
- **D-06:** VisibilityNotifier2D (Godot 4: `VisibleOnScreenNotifier2D`) on each enemy controls gem light on/off via `screen_entered`/`screen_exited` signals.
- **D-07:** No hard cap on simultaneous active lights. Viewport-only culling is sufficient.
- **D-08:** Role-based sizing: Sniper/Beeliner ≈ player ship size (~688 world units wide), Flanker ≈ 75%, Swarmer/Suicider ≈ 50%.
- **D-09:** Claude picks exact scale values per enemy type. All values are `@export`-tunable.

### Claude's Discretion
- Exact `Rect2` constants for each ship sprite region in the 2110×2048 atlas
- Exact `Rect2` constants for each bullet sprite region in the atlas bottom half
- Sprite rotation offset (sprites point "up" in the atlas; need −90° offset to align with Godot's +X facing direction)
- `PointLight2D` position within each enemy scene based on visible gem location in the sprite
- Exact pulse period and energy min/max per enemy type
- Final sprite scale values per enemy (within the role-tier ranges in D-08)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SPR-01 | All 5 enemy types display sprites from ships_assets.png | Sprite2D `region_enabled` + `region_rect` pattern; atlas Rect2 constants computed below |
| SPR-02 | Sprite regions extracted via hardcoded Rect2 constants per enemy type | Atlas measured; constants provided in Code Examples section |
| SPR-03 | If sprite unavailable, enemy falls back to existing Polygon2D shape | `_ready()` pattern: check load result, hide Polygon2D on success, leave visible on failure |
| SPR-04 | Each enemy has pulsing PointLight2D gem glow matching gem color, distance-culled | VisibleOnScreenNotifier2D + Tween ping-pong pattern; existing PointLight2D usage in player ship confirmed |
| SPR-05 | Enemy sprite scale adjusted so apparent size matches player ship | Player ship polygon spans ~688 world units; scale math computed per enemy role tier |
</phase_requirements>

---

## Summary

This phase replaces all five enemy debug Polygon2D shapes with sprites from `ships_assests.png` (2110×2048 RGBA PNG), and adds a pulsing `PointLight2D` gem glow to each enemy. The atlas has 5 ship sprites across the top half and 5 matching bullet sprite sets across the bottom half. All sprites point "up" in the atlas and require a −90° `rotation_offset` on the `Sprite2D` node to align with Godot's +X facing convention used by `look_at()`.

The implementation is purely scene-level work: configure the existing `Sprite2D` node in each enemy scene with `region_enabled = true` and `region_rect`, hide the `Polygon2D` "Shape" node on success (leave visible on failure for SPR-03), add a `VisibleOnScreenNotifier2D` + `PointLight2D` pair, and start a looping `Tween` in `_ready()` to animate `energy`. The same atlas-region pattern applies to the four bullet scenes.

No new scripts need to be created. All configuration lives in the scene files and enemy GDScript `_ready()` extensions. All tunable values (`@export`) are set in the scene so post-playtest tweaks work without re-editing code.

**Primary recommendation:** Configure sprites directly in .tscn files (region_enabled, region_rect, rotation_offset, scale), call `hide()` on the Polygon2D in `_ready()` after confirming texture loaded, and use a `create_tween().set_loops(0).set_trans(TRANS_SINE)` ping-pong for gem pulse.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sprite atlas region extraction | Scene (.tscn) | _ready() GDScript | Static data; set once per enemy type at scene-author time |
| Polygon2D fallback | _ready() GDScript | — | Conditional on texture load success; runtime check |
| PointLight2D gem glow color | Scene (.tscn) | — | Static per enemy type; set in scene inspector |
| Gem light pulse animation | _ready() GDScript (Tween) | — | Needs looping runtime animation; lightest approach per context |
| Visibility culling (light on/off) | Scene node (VisibleOnScreenNotifier2D) | _ready() signal connect | Signal wiring done in _ready(); node placed in scene |
| Scale / size matching | Scene (.tscn) Sprite2D.scale | @export override | Baseline set in scene; tunable via export |
| Bullet sprite regions | Bullet .tscn files | — | Same pattern as ship sprites; no script changes needed |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot `Sprite2D` | 4.6 (local editor) / 4.2.1 (CI) | Display atlas region as 2D sprite | Built-in; existing node already in base-enemy-ship.tscn |
| Godot `PointLight2D` | 4.6 / 4.2.1 | Per-enemy gem glow | Built-in; already used on player ship (confirmed in ship-bfg-23.tscn) |
| Godot `VisibleOnScreenNotifier2D` | 4.6 / 4.2.1 | Emit signals when enemy enters/exits camera viewport | Built-in; preferred over manual distance checks |
| Godot `Tween` (scene-owned) | 4.6 / 4.2.1 | Loop energy pulse on PointLight2D | Built-in; `create_tween()` already used in score-manager.gd |
| Godot `GradientTexture2D` | 4.6 / 4.2.1 | PointLight2D texture (radial falloff) | Same resource type used on player ship propeller lights |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Godot `AtlasTexture` (resource) | 4.6 / 4.2.1 | Alternative to inline region_rect | Use if atlas region needs to be a standalone .tres resource; not needed here |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Sprite2D.region_enabled` + `region_rect` | `AtlasTexture` resource | AtlasTexture is reusable but adds .tres files; inline region_rect on Sprite2D is simpler for this use case |
| Tween ping-pong | AnimationPlayer node | AnimationPlayer adds a node and .anim resource; Tween in _ready() is lighter and established by score-manager.gd |
| VisibleOnScreenNotifier2D signals | Manual distance check in _process | Signal-based is zero-cost when off-screen; _process poll adds overhead for every enemy every frame |

**Installation:** No packages — all Godot built-ins.

**Version note:** project.godot shows `config/features=PackedStringArray("4.6", ...)` indicating local editor is Godot 4.6. CI still uses 4.2.1 (barichello/godot-ci:4.2.1). All APIs used in this phase (`Sprite2D.region_enabled`, `VisibleOnScreenNotifier2D`, `Tween.set_loops`) exist in both versions. [VERIFIED: project.godot, .github/workflows, Context7 Godot 4.4 docs]

---

## Architecture Patterns

### System Architecture Diagram

```
ships_assests.png (2110×2048 atlas)
         |
         | preload() in each enemy _ready()
         v
[Sprite2D] ← region_enabled=true, region_rect=Rect2(...), rotation_offset=-90°, scale=Vector2(...)
         |
         | texture loaded?
    YES  |  NO
    v         v
hide(Polygon2D)  leave Polygon2D visible (fallback, SPR-03)

[VisibleOnScreenNotifier2D]
  screen_entered → PointLight2D.enabled = true
  screen_exited  → PointLight2D.enabled = false

[PointLight2D] ← color, energy animated by Tween
  ↑
[Tween] create_tween().set_loops(0).set_trans(TRANS_SINE)
        tween_property(light, "energy", max_energy, half_period)
        .chain()
        .tween_property(light, "energy", min_energy, half_period)
        (loops indefinitely)
```

### Recommended Project Structure

No new directories needed. Changes are confined to:
```
prefabs/enemies/
├── base-enemy-ship.tscn           # no change needed
├── beeliner/
│   ├── beeliner.tscn              # add Sprite2D config, VisibleOnScreenNotifier2D, PointLight2D
│   └── beeliner-bullet.tscn       # add Sprite2D region config
├── sniper/
│   ├── sniper.tscn                # same
│   └── sniper-bullet.tscn         # same
├── flanker/
│   ├── flanker.tscn               # same
│   └── flanker-bullet.tscn        # same
├── swarmer/
│   ├── swarmer.tscn               # same
│   └── swarmer-bullet.tscn        # same
└── suicider/
    └── suicider.tscn              # same (no bullet scene)
components/
├── beeliner.gd                    # add _setup_sprite() + _setup_gem_light() to _ready()
├── sniper.gd                      # same
├── flanker.gd                     # same
├── swarmer.gd                     # same
└── suicider.gd                    # same
```

### Pattern 1: Sprite2D Atlas Region in _ready()

**What:** Load atlas texture at runtime in `_ready()`, configure `region_rect`, hide fallback Polygon2D on success.

**When to use:** Every enemy ship `_ready()` function.

```gdscript
# Source: Godot 4.4 docs — Sprite2D.region_enabled / region_rect [CITED: docs.godotengine.org/en/4.4]
func _setup_sprite() -> void:
    var atlas: Texture2D = load("res://ships_assests.png")
    if atlas == null:
        # SPR-03 fallback: Polygon2D stays visible
        return
    var sprite := $Sprite2D as Sprite2D
    sprite.texture = atlas
    sprite.region_enabled = true
    sprite.region_rect = SPRITE_REGION  # Rect2 constant defined per enemy type
    sprite.rotation_degrees = -90.0    # atlas sprites point "up"; Godot facing is +X
    sprite.scale = SPRITE_SCALE        # Vector2 constant per enemy type
    $Shape.visible = false              # hide Polygon2D fallback
```

**Key detail:** `load()` returns `null` if the file is missing at runtime (export-safe behavior); `preload()` would cause a compile-time error if the file doesn't exist. Use `load()` for the fallback guard. [VERIFIED: Godot docs — preload vs load]

### Pattern 2: PointLight2D + VisibleOnScreenNotifier2D Setup

**What:** Add `VisibleOnScreenNotifier2D` and `PointLight2D` as scene children, wire signals in `_ready()`.

**When to use:** Every enemy ship `_ready()` after sprite setup.

```gdscript
# Source: Godot 4.4 docs — VisibleOnScreenNotifier2D, PointLight2D [CITED: docs.godotengine.org/en/4.4]
func _setup_gem_light() -> void:
    var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
    var light := $GemLight as PointLight2D
    # Start disabled; notifier enables when on-screen
    light.enabled = false
    notifier.screen_entered.connect(func(): light.enabled = true)
    notifier.screen_exited.connect(func(): light.enabled = false)
    _start_pulse(light)

func _start_pulse(light: PointLight2D) -> void:
    var tween := create_tween()
    tween.set_loops(0)                          # 0 = infinite loops [CITED: docs.godotengine.org/en/4.4]
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(light, "energy", GEM_ENERGY_MAX, GEM_PULSE_HALF_PERIOD)
    tween.tween_property(light, "energy", GEM_ENERGY_MIN, GEM_PULSE_HALF_PERIOD)
```

**Key detail:** `set_loops(0)` means infinite in Godot 4. The tween animates energy min→max→min in a sine wave giving the organic pulse feel. [VERIFIED: Context7 Godot 4.4 docs — Tween.set_loops(loops: int = 1)]

### Pattern 3: PointLight2D Texture (GradientTexture2D)

**What:** PointLight2D requires a texture for radial falloff. Use `GradientTexture2D` with radial fill — same approach as the player ship.

**When to use:** When adding `GemLight` node to each enemy scene.

The player ship already has this pattern (confirmed in ship-bfg-23.tscn):
```
[sub_resource type="GradientTexture2D" id="..."]
gradient = SubResource("Gradient_...")   # white center → transparent edge
width = 300
height = 300
use_hdr = true
fill = 1          # radial fill
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.5, 0.91)
```
[VERIFIED: ship-bfg-23.tscn, lines 25-31]

### Anti-Patterns to Avoid

- **Using `preload()` for the atlas texture fallback:** `preload()` is a compile-time operation — if the file is ever missing from an export, the scene will fail to load entirely. Use `load()` and check for null. [VERIFIED: Godot docs]
- **Pulsing in `_process()` using `sin(Time.get_ticks_msec())`:** Works but adds _process overhead for every enemy. Tween is zero-cost between keyframes and self-cleaning.
- **Enabling PointLight2D shadows on gem lights:** The player ship uses `shadow_enabled = true`, but gem lights on enemies are small, many, and far from shadow-casting geometry. Set `shadow_enabled = false` on gem lights to avoid the shadow rendering cost at wave 20.
- **Setting `VisibleOnScreenNotifier2D.rect` too small:** If the rect is smaller than the sprite, the light may flick off while part of the ship is still on screen. Set rect to cover the full sprite bounding box with a small margin.

---

## Atlas Sprite Region Constants

The atlas is 2110×2048 RGBA. Top half contains 5 ships; bottom half contains 5 bullet sets. Separator band visible at approximately y=1000–1050.

**Column layout (5 equal-ish columns, each ~422px wide):**
- ENM-07 (Beeliner): column 0, x≈0
- ENM-08 (Sniper): column 1, x≈422
- ENM-09 (Flanker): column 2, x≈844
- ENM-10 (Swarmer): column 3, x≈1266
- ENM-11 (Suicider): column 4, x≈1688

**Estimated ship sprite Rect2 constants (Claude's discretion, ASSUMED — require visual verification in editor):**

| Enemy | ENM | Rect2 (x, y, w, h) | Gem color |
|-------|-----|---------------------|-----------|
| Beeliner | ENM-07 | `Rect2(20, 10, 390, 700)` | green |
| Sniper | ENM-08 | `Rect2(440, 10, 380, 780)` | purple |
| Flanker | ENM-09 | `Rect2(870, 30, 360, 720)` | orange |
| Swarmer | ENM-10 | `Rect2(1295, 50, 360, 650)` | yellow/amber |
| Suicider | ENM-11 | `Rect2(1720, 80, 340, 640)` | red |

**Estimated bullet sprite Rect2 constants (bottom half, y≈1050+):**

| Enemy | Primary bullet region |
|-------|----------------------|
| Beeliner | `Rect2(20, 1060, 120, 280)` |
| Sniper | `Rect2(440, 1060, 120, 320)` |
| Flanker | `Rect2(870, 1060, 120, 300)` |
| Swarmer | `Rect2(1295, 1060, 100, 240)` |

**IMPORTANT [ASSUMED]:** These Rect2 values are estimated from the visual layout of the atlas image. They MUST be validated and adjusted by opening the atlas in the Godot Sprite2D inspector and using the "Region" editor to verify exact pixel coordinates before committing. The planner should include a dedicated "Measure atlas regions" task.

---

## Scale Constants

Player ship Polygon2D spans approximately 688 world units wide (from ship-bfg-23.tscn CollisionPolygon2D: x range −344 to 344). [VERIFIED: ship-bfg-23.tscn line 202]

Target apparent sizes (D-08):
- Beeliner: ~688 world units wide → full player size
- Sniper: ~688 world units wide → full player size
- Flanker: ~516 world units wide → 75% of player
- Swarmer: ~344 world units wide → 50% of player
- Suicider: ~344 world units wide → 50% of player

Sprite2D scale formula: `target_world_width / sprite_pixel_width`

**Example for Beeliner (ENM-07, est. sprite width 390px, target 688 world units):**
- scale_x = 688 / 390 ≈ 1.764
- Use `Vector2(1.764, 1.764)` as baseline — adjust after visual check

**[ASSUMED]:** Final scale values depend on verified Rect2 widths. All scale values must be `@export` vars so playtest adjustment is one-click.

---

## Gem Light Pulse Parameters (Claude's Discretion)

All values are `@export` vars for post-playtest tuning. GradientTexture2D needs to be created as sub_resource in each enemy scene (same structure as player ship propeller lights).

| Enemy | Color (RGBA) | Energy Min | Energy Max | Half Period (s) | Pulse Character |
|-------|-------------|------------|------------|-----------------|-----------------|
| Beeliner | `Color(0.0, 0.9, 0.2, 1)` | 0.5 | 1.8 | 0.6 | Steady rhythmic — predictable aggression |
| Sniper | `Color(0.6, 0.0, 1.0, 1)` | 0.2 | 2.5 | 1.5 | Slow hypnotic — long period, wide swing |
| Flanker | `Color(1.0, 0.45, 0.0, 1)` | 0.4 | 1.6 | 0.8 | Mid-tempo rhythmic — steady orbit energy |
| Swarmer | `Color(1.0, 0.75, 0.0, 1)` | 0.3 | 2.0 | 0.25 | Quick flicker — short period, active |
| Suicider | `Color(1.0, 0.05, 0.05, 1)` | 0.6 | 3.0 | 0.15 | Frantic fast — high urgency |

**[ASSUMED]:** Energy ranges and periods are initial estimates tuned for visual feel. They must be verified in-engine during playtest. Making them `@export` allows live adjustment without recompile.

---

## VisibleOnScreenNotifier2D Rect Configuration

The `VisibleOnScreenNotifier2D` node has a `rect` property (a `Rect2` in local space) that defines the visibility detection region. It should cover the sprite extents.

**Recommended approach:** Set `rect` to encompass the sprite bounding box in local coordinates. Since sprites will be scaled, use conservative values:
- Beeliner/Sniper: `Rect2(-400, -400, 800, 800)` (roughly covers scaled sprite)
- Flanker: `Rect2(-300, -300, 600, 600)`
- Swarmer/Suicider: `Rect2(-200, -200, 400, 400)`

These can be set in the .tscn file directly. [ASSUMED — verify against final scale values]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sprite atlas cropping | Custom shader or pixel-copy code | `Sprite2D.region_enabled` + `region_rect` | Built-in Godot feature; GPU-accelerated; no runtime cost |
| Light pulsing | `_process()` sin-wave energy update | `Tween.set_loops(0)` with `tween_property` | Tween is zero-cost between frames; no per-frame callback |
| Visibility culling | Distance check in `_process()` | `VisibleOnScreenNotifier2D` | Signal-based; zero cost when off-screen |
| Radial light falloff texture | Custom gradient PNG | `GradientTexture2D` sub_resource | Godot built-in; same approach already on player ship |

**Key insight:** Every sub-problem in this phase has an established Godot built-in solution. The entire implementation is configuration of existing nodes, not new code systems.

---

## Common Pitfalls

### Pitfall 1: preload() Crash on Missing Atlas

**What goes wrong:** Using `preload("res://ships_assests.png")` at script top causes a compile-time error if the file is missing from export. The fallback (SPR-03) becomes unreachable.

**Why it happens:** `preload()` runs at parse time. If the texture is absent, the script fails before `_ready()` runs.

**How to avoid:** Use `load("res://ships_assests.png")` inside `_ready()` and check for `null`. Only hide Polygon2D if load succeeded.

**Warning signs:** Script parse errors in export logs; fallback never triggers in testing.

### Pitfall 2: Atlas Not Auto-Imported (Missing .import File)

**What goes wrong:** `ships_assests.png` has no `.import` file yet (confirmed: only `ship.png` and `ship-inventory.png` have import files in `.godot/imported/`). Godot must auto-import it on first editor open before it can be loaded at runtime.

**Why it happens:** New files added to the filesystem must be imported by the editor before they are usable as textures.

**How to avoid:** Open the Godot editor with the project after adding the atlas reference. The editor will auto-import. Verify `ships_assests.png.import` file appears in project root after first open. The atlas should be imported as "Texture2D" (default) — no special atlas import needed since `region_rect` handles cropping.

**Warning signs:** `load()` returns null even though the file exists; black/empty sprite in game.

### Pitfall 3: Sprite Rotation Alignment

**What goes wrong:** Sprites render pointing "up" (+Y) but the enemy faces +X direction (set by `look_at()`). The ship appears rotated 90° wrong.

**Why it happens:** Atlas art convention is "up-facing"; Godot's 2D convention for `look_at()` and bullet firing is +X facing.

**How to avoid:** Set `Sprite2D.rotation_degrees = -90.0` (or equivalently `rotation = -1.5708` radians) in the .tscn file. This is the same fix already applied to bullet Sprite2D nodes (confirmed: sniper-bullet.tscn and beeliner-bullet.tscn already have `rotation = 1.5708` on their Sprite2D nodes — note those rotate the collision shape; for ship sprites use rotation_offset on the Sprite2D or rotation on the node itself).

**Warning signs:** Ship appears to move sideways relative to its sprite orientation.

### Pitfall 4: PointLight2D Shadows on Many Enemies

**What goes wrong:** Enabling `shadow_enabled = true` on gem lights causes a significant FPS drop at wave 20 (20+ enemies on screen simultaneously).

**Why it happens:** Each shadow-casting PointLight2D requires an additional shadow render pass per occluder. With many enemies and existing shadow casters (player ship, asteroids), this multiplies.

**How to avoid:** Set `shadow_enabled = false` on all gem lights. Gem lights are decorative; shadow accuracy is not needed for the effect. [VERIFIED: player ship uses shadow_enabled = true for its main structural light — that's one light, not 20+]

**Warning signs:** FPS drops from 100 to <60 at late waves; GPU profiler shows shadow render calls scaling with enemy count.

### Pitfall 5: Tween Created Before Node is in Tree

**What goes wrong:** Calling `create_tween()` before the node has entered the scene tree can create an invalid tween.

**Why it happens:** `create_tween()` requires the node to have a valid `SceneTree`.

**How to avoid:** Create the tween inside `_ready()` only — never in `_init()` or before `super()`. The `_ready()` pattern in beeliner.gd already calls `super()` first.

**Warning signs:** Tween is_valid() returns false; no pulse visible.

### Pitfall 6: Sprite2D Scale Interacts with Collision

**What goes wrong:** Scaling `Sprite2D` changes visual size only, not collision. CollisionShape2D remains at its original radius (300 for all enemies). This is actually DESIRED — collision is independent of sprite size per established design.

**Why it happens:** `Sprite2D.scale` affects rendering only.

**How to avoid:** Do NOT scale the root RigidBody2D node. Scale only the Sprite2D child node. Collision shapes remain unchanged. [VERIFIED: beeliner.tscn, sniper.tscn — CircleShape2D radius=300 for all enemy types regardless of intended visual size]

**Warning signs:** If you accidentally scale the parent RigidBody2D, physics go wrong (forces are in world space but shape is scaled).

---

## Code Examples

### Ship Scene Addition — Beeliner example

```gdscript
# Source: Established project pattern from beeliner.gd _ready()
# Add to each enemy type's _ready() after super()

const SPRITE_REGION := Rect2(20, 10, 390, 700)   # [ASSUMED: verify in editor]
const SPRITE_SCALE := Vector2(1.76, 1.76)          # [ASSUMED: 688/390]
const GEM_ENERGY_MIN := 0.5
const GEM_ENERGY_MAX := 1.8
const GEM_PULSE_HALF_PERIOD := 0.6
@export var sprite_region: Rect2 = SPRITE_REGION
@export var sprite_scale: Vector2 = SPRITE_SCALE
@export var gem_energy_min: float = GEM_ENERGY_MIN
@export var gem_energy_max: float = GEM_ENERGY_MAX
@export var gem_pulse_half_period: float = GEM_PULSE_HALF_PERIOD

func _ready() -> void:
    super()
    _setup_sprite()
    _setup_gem_light()

func _setup_sprite() -> void:
    var atlas: Texture2D = load("res://ships_assests.png")
    if atlas == null:
        return  # SPR-03: Polygon2D stays visible
    var sprite := $Sprite2D as Sprite2D
    sprite.texture = atlas
    sprite.region_enabled = true
    sprite.region_rect = sprite_region
    sprite.rotation_degrees = -90.0
    sprite.scale = sprite_scale
    $Shape.visible = false

func _setup_gem_light() -> void:
    var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
    var light := $GemLight as PointLight2D
    light.enabled = false
    notifier.screen_entered.connect(func(): light.enabled = true)
    notifier.screen_exited.connect(func(): light.enabled = false)
    _start_pulse(light)

func _start_pulse(light: PointLight2D) -> void:
    var tween := create_tween()
    tween.set_loops(0)
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(light, "energy", gem_energy_max, gem_pulse_half_period)
    tween.tween_property(light, "energy", gem_energy_min, gem_pulse_half_period)
```

### Scene Node Additions (snippet for beeliner.tscn)

```
# Add these nodes as children of the Beeliner RigidBody2D:

[sub_resource type="GradientTexture2D" id="GradientTexture2D_gem"]
gradient = SubResource("Gradient_gem_beeliner")
width = 256
height = 256
use_hdr = true
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.5, 1.0)

[sub_resource type="Gradient" id="Gradient_gem_beeliner"]
colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)

[node name="GemLight" type="PointLight2D" parent="."]
position = Vector2(0, 0)      # [ASSUMED: adjust to gem location in sprite]
color = Color(0.0, 0.9, 0.2, 1)
energy = 0.5
shadow_enabled = false
texture = SubResource("GradientTexture2D_gem")
texture_scale = 8.0

[node name="VisibleOnScreenNotifier2D" type="VisibleOnScreenNotifier2D" parent="."]
rect = Rect2(-400, -400, 800, 800)
```

### Bullet Scene Update (snippet — no script changes)

```
# In beeliner-bullet.tscn, configure the existing Sprite2D node:
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("atlas_texture")    # add ext_resource ref to ships_assests.png
region_enabled = true
region_rect = Rect2(20, 1060, 120, 280)  # [ASSUMED: verify in editor]
rotation = 1.5708                          # existing rotation kept (already present)
scale = Vector2(0.3, 0.3)                 # [ASSUMED: adjust to match bullet collision shape]
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `VisibilityNotifier2D` (Godot 3) | `VisibleOnScreenNotifier2D` (Godot 4) | Godot 4.0 | Class renamed; same signals `screen_entered` / `screen_exited` |
| `Tween.interpolate_property()` (Godot 3) | `create_tween().tween_property()` (Godot 4) | Godot 4.0 | New scene-owned tween API; `set_loops(0)` replaces old `repeat` param |
| `get_node("VisibilityNotifier2D")` | `$VisibleOnScreenNotifier2D` | Godot 4.0 | Node name changed; @onready shorthand works |

**Deprecated/outdated:**
- `VisibilityNotifier2D`: Godot 3 name — does not exist in Godot 4. Use `VisibleOnScreenNotifier2D`.
- `Tween.start()` / `Tween.interpolate_property()`: Godot 3 API. Not needed in Godot 4 scene-owned tweens.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Sprite Rect2 values for all 5 ships (e.g., Beeliner: Rect2(20, 10, 390, 700)) | Atlas Sprite Region Constants | Wrong crop shows wrong part of atlas; easily fixed in editor |
| A2 | Bullet Rect2 values for all 4 bullet types | Atlas Sprite Region Constants | Same — wrong crop; editor-fixable |
| A3 | scale values per enemy (e.g., Vector2(1.76, 1.76) for Beeliner) | Scale Constants | Wrong visual size; @export makes it one-click to fix |
| A4 | Gem light energy ranges and pulse periods per enemy type | Gem Light Pulse Parameters | Light feels wrong tonally; tunable via @export |
| A5 | VisibleOnScreenNotifier2D rect sizes per enemy | VisibleOnScreenNotifier2D Rect | Light flickers at screen edge if rect too small; adjust in editor |
| A6 | GemLight position Vector2(0, 0) — gem is at sprite center | Scene Node Additions | Light appears offset from visible gem; adjust position per sprite |

**All A1–A6 are verified by opening the atlas in the Godot sprite region editor and checking positions visually — a "Measure atlas regions" task is required.**

---

## Open Questions (RESOLVED)

1. **Is `ships_assests.png` (note the typo: "assests" not "assets") the final filename?**
   - What we know: File exists at project root with that exact name (confirmed via `ls`).
   - What's unclear: Whether the typo will be corrected before implementation.
   - Recommendation: Use the filename as-is (`ships_assests.png`). If renamed, update all `load()` calls in one pass.
   - RESOLVED: Use `ships_assests.png` as-is. All plans reference this exact filename consistently.

2. **Should Polygon2D "Shape" be hidden via scene property or script?**
   - What we know: Context says hide via `visible = false` when sprite loads successfully in `_ready()`.
   - What's unclear: Whether to set `visible = false` in the .tscn and rely on SPR-03 path only for showing it.
   - Recommendation: Default `Shape.visible = true` in .tscn (unchanged). Script sets `$Shape.visible = false` only after successful atlas load. This preserves the fallback path cleanly.
   - RESOLVED: Scene defaults to `Shape.visible = true` (unchanged). `_setup_sprite()` sets `$Shape.visible = false` only after successful `load()` — preserves SPR-03 fallback path cleanly (Plan 15-01).

3. **What process_mode should GemLight and VisibleOnScreenNotifier2D use?**
   - What we know: Context notes PointLight2D must have `process_mode` set correctly for death screen pause behavior.
   - What's unclear: Whether enemies are paused on death screen.
   - Recommendation: Set both nodes to `PROCESS_MODE_PAUSABLE` (default). If enemies are frozen during pause, the Tween will also pause — acceptable behavior.
   - RESOLVED: Default `PROCESS_MODE_PAUSABLE` accepted — no override set in scenes (Plan 15-02). If enemies freeze during pause, the Tween also pauses, which is acceptable.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot Editor | Scene editing, atlas region measurement | ✓ | 4.6 (local editor detected from project.godot) | — |
| ships_assests.png | All sprite work | ✓ | 2110×2048 RGBA (confirmed via `file` command) | — |
| Godot CI image | Build validation | ✓ | 4.2.1 (barichello/godot-ci) | — |

**No missing dependencies.** All required assets and tools are available.

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: /Users/milan.kormout/Projects/personal/graviton/prefabs/enemies/beeliner/beeliner.tscn] — confirmed Polygon2D "Shape" node pattern, existing Sprite2D node, collision radius
- [VERIFIED: /Users/milan.kormout/Projects/personal/graviton/prefabs/ship-bfg-23/ship-bfg-23.tscn] — confirmed PointLight2D + GradientTexture2D pattern, player ship polygon ~688 units wide
- [VERIFIED: /Users/milan.kormout/Projects/personal/graviton/components/score-manager.gd] — confirmed `create_tween().set_parallel()` usage pattern in codebase
- [VERIFIED: /Users/milan.kormout/Projects/personal/graviton/ships_assests.png] — visual inspection of atlas, confirmed 5 ships top half / 5 bullet sets bottom half / 2110×2048 size
- [VERIFIED: /Users/milan.kormout/Projects/personal/graviton/project.godot] — Godot 4.6 local editor confirmed
- [CITED: docs.godotengine.org/en/4.4] — Sprite2D region_enabled/region_rect, VisibleOnScreenNotifier2D signals, Tween.set_loops(0) via Context7 /websites/godotengine_en_4_4

### Secondary (MEDIUM confidence)
- [VERIFIED: .github/workflows CI config] — Godot 4.2.1 CI image confirmed; all APIs used in this phase available in 4.2.1

### Tertiary (LOW confidence)
- Sprite Rect2 pixel coordinates (A1, A2) — estimated from visual inspection of atlas image; must be verified in Godot sprite region editor

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — all built-in Godot nodes, confirmed in existing project files
- Architecture: HIGH — pattern is direct extension of existing codebase conventions (beeliner.gd _ready, player ship PointLight2D)
- Atlas Rect2 constants: LOW — estimated from image; must be verified in editor
- Scale constants: LOW — derived from estimated Rect2 widths; must be verified visually
- Pulse parameters: LOW — initial creative estimates; all @export-tunable
- Pitfalls: HIGH — verified against actual code and Godot 4 docs

**Research date:** 2026-04-17
**Valid until:** 2026-07-17 (stable Godot APIs)
