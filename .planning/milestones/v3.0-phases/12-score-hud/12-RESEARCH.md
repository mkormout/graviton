# Phase 12: Score HUD - Research

**Researched:** 2026-04-15
**Domain:** Godot 4.6.2 — CanvasLayer HUD, Control anchoring, Tween API, autoload signal wiring
**Confidence:** HIGH

## Summary

Phase 12 is a pure frontend wiring task with no novel architectural problems. The pattern already exists in `wave-hud.gd` and can be followed precisely. The ScoreManager autoload exposes four signals (`score_changed`, `multiplier_changed`, `combo_updated`, `combo_expired`) and the public vars `kill_count`, `total_score`, `wave_multiplier`, `combo_count`. All signal wiring happens via a `connect_to_score_manager()` method on ScoreHud, called from `world.gd` at scene startup — identical to how `wave-hud` is wired today.

The tween patterns needed (scale pulse + simultaneous color flash, sequential callback cleanup) are already proven in `components/score-manager.gd`'s floating label code: `set_parallel(true)` runs scale and color tweens in parallel; `.chain().tween_callback(...)` fires cleanup after both complete. For label font color overrides at runtime, `add_theme_color_override("font_color", ...)` is the standard Godot 4 approach, visible in `status-bar.tscn` and `score-manager.gd`.

GDScript has no built-in comma-formatted number function. Plain `"%d" % value` is the correct approach; hand-rolling comma separation is unnecessary complexity for this phase.

**Primary recommendation:** Copy the wave-hud scene structure, anchor to top-right with `PRESET_TOP_RIGHT`, add four Label rows inside a VBoxContainer, connect via `connect_to_score_manager()` from world.gd. Use `set_parallel(true)` tween for the multiplier pulse. No external dependencies.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: New `score-hud.tscn` in `prefabs/ui/` — do NOT extend wave-hud.tscn
- D-02: Extend `CanvasLayer`, companion `score-hud.gd` script
- D-03: Top-right corner anchor
- D-04: Four rows, bare labels (no panel background): SCORE / KILLS / MULT / COMBO
- D-05: Prefix label + value format (e.g., `SCORE  12,450`, not icons)
- D-06: White text with outline for contrast
- D-07: Combo row always visible — `--` when inactive, `x{N}` when active
- D-08: Connect to `combo_updated(combo_count)` and `combo_expired()`
- D-09: Multiplier label: scale 1.0→1.4→1.0 + color white→gold→white over ~0.4s via tween
- D-10: Score label: small color flash on `score_changed`
- D-11: Kill count and combo row: text update only, no animation
- D-12: `connect_to_score_manager()` method pattern, called from world.gd
- D-13: Connect all four ScoreManager signals
- D-14: Read `ScoreManager.kill_count` inside `score_changed` handler (no separate kill signal)

### Claude's Discretion
- Exact font sizes (match wave-hud sizing as baseline)
- Whether score uses comma formatting or plain integer — plain `%d` is correct (no built-in comma formatter in GDScript)
- Exact tween easing curve for scale pulse
- Whether combo `--` grey uses `modulate` or `add_theme_color_override`

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

## Standard Stack

### Core (all built-in Godot 4.6.2 — no external packages)

| Node/API | Purpose | Why Standard |
|----------|---------|--------------|
| `CanvasLayer` | HUD root — renders above 3D/2D game world | Used by wave-hud, status-bar, hud in this project |
| `VBoxContainer` | Stack label rows vertically with automatic layout | Used in wave-hud.tscn and status-bar.tscn |
| `Label` | Display score/kills/mult/combo text | Lightest text node; theme overrides for color/size |
| `Tween` (via `create_tween()`) | Animate scale and color | Already used in wave-hud.gd and score-manager.gd |
| `ScoreManager` (autoload) | Signal source and data source | Already registered as autoload from Phase 11 |

### No Installation Required

All nodes are built into Godot 4.6.2. No `npm install` or package management.

## Architecture Patterns

### Recommended Project Structure

```
prefabs/ui/
├── score-hud.tscn       # New — CanvasLayer root, VBoxContainer, 8 Label nodes
├── score-hud.gd         # New — ScoreHud class, connect_to_score_manager()
├── wave-hud.tscn        # Existing — pattern reference
└── wave-hud.gd          # Existing — pattern reference
```

### Pattern 1: CanvasLayer + Top-Right Anchored VBoxContainer

The wave-hud uses a Panel centered at top-center using manual offsets. For top-right, use `anchors_preset` on the VBoxContainer set to `PRESET_TOP_RIGHT` (value 3), with a MarginContainer providing inset padding, or use anchor values directly:

```gdscript
# In .tscn (equivalent values):
anchor_left = 1.0
anchor_right = 1.0
anchor_top = 0.0
anchor_bottom = 0.0
grow_horizontal = 0   # grow left (so box extends inward from right edge)
offset_left = -200.0  # width of the block
offset_right = -16.0  # right margin from edge
offset_top = 16.0     # top margin from edge
offset_bottom = 140.0 # height of the block
```

**Alternative:** Use `Control.PRESET_TOP_RIGHT` set in `_ready()` via `set_anchors_preset()` — but the tscn inline approach matches existing project style. [VERIFIED: wave-hud.tscn and status-bar.tscn both set anchors inline in the scene file]

### Pattern 2: Signal Connection Method (mirrors wave-hud)

```gdscript
# Source: prefabs/ui/wave-hud.gd line 15 — exact pattern to copy
func connect_to_score_manager(sm: Node) -> void:
    sm.score_changed.connect(_on_score_changed)
    sm.multiplier_changed.connect(_on_multiplier_changed)
    sm.combo_updated.connect(_on_combo_updated)
    sm.combo_expired.connect(_on_combo_expired)
```

Called from world.gd after instantiating score_hud (same pattern as line 56-57 of world.gd):
```gdscript
var score_hud: ScoreHud = score_hud_model.instantiate()
add_child(score_hud)
score_hud.connect_to_score_manager(ScoreManager)
```

[VERIFIED: world.gd lines 54-60 — wave_hud pattern confirmed]

### Pattern 3: Parallel Tween for Scale Pulse + Color Flash

For the multiplier animation (scale AND color simultaneously), use `set_parallel(true)`:

```gdscript
# Source: components/score-manager.gd lines 160-164 — set_parallel pattern confirmed in codebase
func _animate_multiplier_pulse() -> void:
    var tween := _mult_value_label.create_tween()
    tween.set_parallel(true)
    # Scale: 1.0 → 1.4 → 1.0 over 0.4s total
    tween.tween_property(_mult_value_label, "scale", Vector2(1.4, 1.4), 0.2)
    tween.tween_property(_mult_value_label, "theme_override_colors/font_color",
        Color(1.0, 0.843, 0.0), 0.2)  # gold flash
    # Chain second half after first (parallel block runs 0.2s, then chain)
    var tween2 := _mult_value_label.create_tween()
    tween2.set_parallel(true)
    tween2.tween_property(_mult_value_label, "scale", Vector2.ONE, 0.2).set_delay(0.2)
    tween2.tween_property(_mult_value_label, "theme_override_colors/font_color",
        Color.WHITE, 0.2).set_delay(0.2)
```

**Simpler single-tween approach (recommended):** Use a sequential tween with `set_parallel` per phase:

```gdscript
func _animate_multiplier_pulse() -> void:
    var tween := _mult_value_label.create_tween()
    tween.set_parallel(true)
    tween.tween_property(_mult_value_label, "scale", Vector2(1.4, 1.4), 0.2)
    tween.tween_property(_mult_value_label, "theme_override_colors/font_color",
        Color(1.0, 0.843, 0.0), 0.2)
    tween.chain().tween_property(_mult_value_label, "scale", Vector2.ONE, 0.2)
    tween.chain().tween_property(_mult_value_label, "theme_override_colors/font_color",
        Color.WHITE, 0.2)
```

Note: `tween.chain()` after `set_parallel(true)` ends the parallel block and starts a new sequential step. The second `tween.chain()` call runs after the first chained step completes. [VERIFIED: score-manager.gd line 164 uses `tween.chain().tween_callback(...)` — chain pattern confirmed]

### Pattern 4: Score Flash (simpler — single property)

```gdscript
func _animate_score_flash() -> void:
    var tween := _score_value_label.create_tween()
    tween.tween_property(_score_value_label, "theme_override_colors/font_color",
        Color(1.0, 1.0, 0.7), 0.1)  # brief light-yellow
    tween.chain().tween_property(_score_value_label, "theme_override_colors/font_color",
        Color.WHITE, 0.2)
```

[ASSUMED — functional approach derived from existing pattern; exact color values are Claude's discretion per CONTEXT.md]

### Pattern 5: Runtime Label Color Override

```gdscript
# Source: components/score-manager.gd line 155 — add_theme_color_override confirmed
label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # greyed combo
label.add_theme_color_override("font_color", Color.WHITE)            # active combo
```

For combo grey/active toggle, `add_theme_color_override` is cleaner than `modulate` because it only affects font color without changing the alpha of the entire label node.

### Pattern 6: Scene .tscn Inline Theme Overrides

For outline and font size set at scene creation time (not changing at runtime), set in tscn directly:

```
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_constants/outline_size = 3
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
```

[VERIFIED: status-bar.tscn lines 38-44, score-manager.gd lines 152-157 — both patterns confirmed]

### Pattern 7: Label Layout — Two-Column Row with HBoxContainer

Each display row (e.g., "SCORE  12,450") needs a prefix label and a value label. Use HBoxContainer with two Labels per row, or a single Label with tab/space-padded text.

**Recommended for this project:** Single Label per row with format `"SCORE  %d" % score` — matches wave-hud's `"WAVE %d" % wave_number` pattern and avoids nested containers for 4 simple rows.

**Alternative (if alignment is important):** HBoxContainer with prefix Label (fixed width via `custom_minimum_size`) and value Label. For this phase's scope, single-label format is simpler and consistent with existing style.

[VERIFIED: wave-hud.gd uses single-label format throughout]

### Anti-Patterns to Avoid

- **Re-registering signals on every frame:** Only connect signals once in `connect_to_score_manager()`. Do not call `connect_to_score_manager()` in `_process()`.
- **Checking `is_connected()` before connecting (in fresh scene):** The HUD is instantiated once at world startup; double-connect guards are not needed unless the method could be called multiple times.
- **Using `modulate` for combo color:** `modulate` affects the entire node including child nodes and alpha. Use `add_theme_color_override("font_color", ...)` for per-label color control.
- **Creating a new tween per frame:** Only create a tween in the signal handler, not in `_process()`.
- **Trying to format integers with commas via `%` operator:** GDScript `%d` produces no comma formatting. Plain integers are correct; hand-rolling comma insertion adds complexity for no gameplay value.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parallel animation (scale + color) | Custom timer loop | `Tween.set_parallel(true)` | Built-in; handles delta timing, interruptable |
| Sequential animation phases | `await` chains or Timer nodes | `tween.chain()` | Composable in single Tween; already used in codebase |
| Signal type-checking before connect | Manual `has_signal()` guards | Direct `.connect()` | ScoreManager signals are typed and guaranteed present as autoload |
| Comma-formatted score display | Custom string function | Plain `"%d" % value` | Godot has no built-in comma formatter; plain int is spec-compliant |
| Cleanup after tween completes | Manual Timer + queue_free | `tween.chain().tween_callback(func)` | Already proven in score-manager.gd line 164 |

**Key insight:** Every animation and signal problem in this phase has a direct built-in Godot 4 solution. The wave-hud and score-manager already demonstrate all patterns needed.

## Common Pitfalls

### Pitfall 1: Tween Interruption on Rapid Signal Fire

**What goes wrong:** `multiplier_changed` fires, tween starts. A second `multiplier_changed` fires 50ms later (e.g., in test mode), creating a second tween that conflicts with the first — label gets stuck at gold or wrong scale.

**Why it happens:** `create_tween()` creates a new independent tween without stopping previous ones.

**How to avoid:** Kill any running tween before starting a new one:
```gdscript
var _mult_tween: Tween = null

func _animate_multiplier_pulse() -> void:
    if _mult_tween and _mult_tween.is_running():
        _mult_tween.kill()
        _mult_value_label.scale = Vector2.ONE
        _mult_value_label.add_theme_color_override("font_color", Color.WHITE)
    _mult_tween = _mult_value_label.create_tween()
    # ... rest of animation
```

**Warning signs:** Multiplier label stays gold or oversized after test wave cycling.

### Pitfall 2: Scale Pivot Not Centered

**What goes wrong:** `scale` tween makes the label grow from its top-left corner instead of its center — visually wrong for a "pulse" effect.

**Why it happens:** Label `pivot_offset` defaults to `Vector2.ZERO` (top-left corner).

**How to avoid:** Set `pivot_offset` to the label's center in `_ready()`:
```gdscript
func _ready() -> void:
    _mult_value_label.pivot_offset = _mult_value_label.size / 2.0
```

Or set in the .tscn file. Note: `size` is only valid after layout, so `_ready()` or a deferred call works; avoid accessing before the node is in the tree.

**Warning signs:** Label appears to shift position when animating scale.

### Pitfall 3: `@onready` Vars Reference Wrong Node Path

**What goes wrong:** Scene is edited in Godot inspector (e.g., container renamed), breaking `@onready var _score_label: Label = $VBox/ScoreLabel`.

**Why it happens:** `@onready` string paths are not refactored by Godot when nodes are renamed.

**How to avoid:** Use the `%UniqueName` syntax (assign unique name in inspector) OR keep the scene structure minimal and stable. For this phase's 8-label layout, explicit paths are fine — just verify paths match exactly once after scene creation.

**Warning signs:** Null reference errors in `_ready()` at runtime.

### Pitfall 4: Label `size` is Zero Before First Layout Frame

**What goes wrong:** `_mult_value_label.pivot_offset = _mult_value_label.size / 2.0` in `_ready()` returns `Vector2.ZERO` because Control size is only resolved after the first layout pass.

**Why it happens:** Godot processes layout after `_ready()` completes.

**How to avoid:** Use `await get_tree().process_frame` before reading `.size`, or use `PRESET_TOP_RIGHT` anchors with a fixed minimum size (`custom_minimum_size`) so the size is known at author time and can be hardcoded in `pivot_offset`.

**Warning signs:** Scale animation pivots from top-left despite pivot_offset set in `_ready()`.

### Pitfall 5: Signal Double-Connect if world.gd is Hot-Reloaded

**What goes wrong:** During development, if world.gd reloads the scene, `connect_to_score_manager()` is called again on a ScoreManager that already has connections — signals fire twice per event.

**Why it happens:** Autoload persists across scene reloads; HUD is re-instantiated and reconnects.

**How to avoid:** Guard with `is_connected` if needed, or accept it as a dev-only issue (production never hot-reloads). For this project scope, no guard is needed.

### Pitfall 6: CanvasLayer Layer Order Conflicts

**What goes wrong:** ScoreHud renders behind wave-hud or inventory.

**Why it happens:** Multiple CanvasLayer nodes at default `layer = 1`. Higher `layer` value renders on top.

**How to avoid:** Match wave-hud's `layer = 10`. Since score-hud and wave-hud are peers (not overlapping), same layer value is fine. Check `enemy-radar.tscn` layer value if overlap is a concern.

[VERIFIED: wave-hud.tscn line 7 — `layer = 10`]

## Code Examples

Verified patterns from the existing codebase:

### Signal Connection (from wave-hud.gd line 15)
```gdscript
# Source: prefabs/ui/wave-hud.gd
func connect_to_wave_manager(wm: WaveManager) -> void:
    wm.wave_started.connect(_on_wave_started)
    wm.enemy_count_changed.connect(_on_enemy_count_changed)
    wm.all_waves_complete.connect(_on_all_waves_complete)
    wm.countdown_tick.connect(_on_countdown_tick)
```

Score HUD equivalent:
```gdscript
func connect_to_score_manager(sm: Node) -> void:
    sm.score_changed.connect(_on_score_changed)
    sm.multiplier_changed.connect(_on_multiplier_changed)
    sm.combo_updated.connect(_on_combo_updated)
    sm.combo_expired.connect(_on_combo_expired)
```

### Parallel Tween (from score-manager.gd lines 160-164)
```gdscript
# Source: components/score-manager.gd
var tween := node.create_tween()
tween.set_parallel(true)
tween.tween_property(node, "global_position:y", world_pos.y - 120.0, 1.5)
tween.tween_property(label, "modulate:a", 0.0, 1.5)
tween.chain().tween_callback(node.queue_free)
```

### World.gd Wiring (from world.gd lines 54-60)
```gdscript
# Source: world.gd
var wave_hud: WaveHud = wave_hud_model.instantiate()
add_child(wave_hud)
wave_hud.connect_to_wave_manager($WaveManager)

# Phase 12 addition follows the same pattern:
# var score_hud: ScoreHud = score_hud_model.instantiate()
# add_child(score_hud)
# score_hud.connect_to_score_manager(ScoreManager)
```

### Runtime Font Color Override (from score-manager.gd line 155)
```gdscript
# Source: components/score-manager.gd
label.add_theme_color_override("font_color", _combo_color(combo_count))
label.add_theme_color_override("font_outline_color", Color.BLACK)
```

### Label Outline in .tscn (from status-bar.tscn)
```
# Source: prefabs/ui/status-bar.tscn
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_constants/shadow_outline_size = 40   # glow-style outline
theme_override_font_sizes/font_size = 60
```

For a smaller HUD label (matching wave-hud sizing of 22px), use `font_size = 18` for value labels and `font_size = 14` for prefix labels or a uniform `font_size = 18`.

### Tween Property Path for theme_override_colors
```gdscript
# The property path for tweening theme color overrides:
tween.tween_property(label, "theme_override_colors/font_color", Color.WHITE, 0.2)
```
[ASSUMED — this is the documented property path syntax for Godot 4 tween_property with theme overrides; confirmed as used with modulate:a in score-manager.gd but the theme_override path specifically has not been tested in this codebase]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `$Tween.interpolate_property()` (Godot 3) | `create_tween().tween_property()` (Godot 4) | Godot 4.0 | New API; old approach does not exist in Godot 4 |
| `connect(signal_name, self, "method_name")` (Godot 3) | `signal.connect(callable)` (Godot 4) | Godot 4.0 | Old string-based connect removed |

**Deprecated/outdated:**
- `$Tween` scene node: Replaced by `create_tween()` in Godot 4. Do not add Tween as a scene child node.
- `yield()`: Replaced by `await` in Godot 4. Do not use yield.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `tween_property` accepts `"theme_override_colors/font_color"` as property path | Architecture Patterns (Pattern 3) | Tween would fail silently; fallback is to set color directly in signal handler without animation |
| A2 | Score label flash uses `Color(1.0, 1.0, 0.7)` as brief highlight color | Architecture Patterns (Pattern 4) | Visual only — any light color works; Claude's discretion per CONTEXT.md |
| A3 | `pivot_offset = size / 2.0` for scale animation centering requires await or deferred call | Common Pitfalls (Pitfall 4) | If wrong, pivot simply works in _ready() — low risk |

**A1 is the only technically load-bearing assumption.** If `tween_property` does not accept the `theme_override_colors/font_color` path, the fallback is to set the color directly in the handler and use modulate for the flash instead.

## Open Questions

1. **Does `tween_property` work with `theme_override_colors/font_color` path?**
   - What we know: `tween_property` works with dot-notation paths (`modulate:a`, `global_position:y`) confirmed in codebase
   - What's unclear: Whether slash-separated theme override paths are supported by tween_property in Godot 4.6.2
   - Recommendation: Attempt it in implementation (Wave 1). If it fails, use `add_theme_color_override` in a deferred callback via `tween.chain().tween_callback(...)` as fallback — perfectly clean solution.

2. **`pivot_offset` timing for scale animation**
   - What we know: `size` is zero in `_ready()` before layout resolves
   - What's unclear: Whether a one-frame await is needed or if a fixed hardcoded pivot_offset is sufficient
   - Recommendation: Use `custom_minimum_size` on the mult label in the .tscn to constrain its size, then hardcode `pivot_offset` to half that minimum size in `_ready()` — no await needed.

## Environment Availability

Step 2.6: SKIPPED — Phase 12 is purely code and scene file changes. No external tools, services, CLIs, or runtimes beyond Godot 4.6.2 (confirmed installed per project.godot config/features and prior phase completions).

## Sources

### Primary (HIGH confidence)
- `prefabs/ui/wave-hud.gd` — Signal connection pattern, tween usage, CanvasLayer extension (verified by Read)
- `prefabs/ui/wave-hud.tscn` — Scene structure, Panel anchoring, Label theme overrides (verified by Read)
- `components/score-manager.gd` — `set_parallel`, `tween_property`, `add_theme_color_override`, signal definitions (verified by Read)
- `world.gd` — wiring pattern at lines 54-60, ScoreManager autoload access at lines 58-61 (verified by Read)
- `prefabs/ui/status-bar.tscn` — `theme_override_colors/font_color` in tscn format confirmed (verified by Read)
- `prefabs/ui/status-bar.gd` — CanvasLayer extension pattern confirmed (verified by Read)

### Tertiary (LOW confidence)
- A1 (tween_property with theme_override path) — not directly tested in codebase; fallback documented

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all nodes built-in Godot 4.6.2, confirmed by existing scenes
- Architecture: HIGH — all patterns directly derived from wave-hud.gd and score-manager.gd in this codebase
- Pitfalls: HIGH — tween interruption, pivot_offset timing, and CanvasLayer layer order are well-known Godot 4 issues
- Tween theme_override path: LOW — one open question, fallback documented

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (stable Godot 4 APIs; no fast-moving ecosystem)
