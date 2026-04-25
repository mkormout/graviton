---
phase: 260425-dnx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - components/enemy-ship.gd
  - world.gd
  - prefabs/ui/controls-hint.tscn
autonomous: false
requirements:
  - QT-260425-DNX-01
must_haves:
  truths:
    - "On game start, every enemy shows its Sprite2D and its Polygon2D Shape is hidden (default state)."
    - "Pressing SHIFT+D once hides every live enemy's Sprite2D and shows every live enemy's Polygon2D Shape."
    - "Pressing SHIFT+D again restores Sprite2D-visible / Shape-hidden on every live enemy."
    - "Enemies that spawn AFTER a toggle adopt the current debug-visible state at spawn time (toggle survives across waves)."
    - "Plain D (no SHIFT) still unmounts the right-side weapon — SHIFT+D never triggers an unmount."
  artifacts:
    - path: "components/enemy-ship.gd"
      provides: "set_debug_visible(show_debug: bool) instance method + add_to_group('enemies') in _ready() + initial Shape.visible defaulted to false on _ready() (overrides .tscn default)."
      contains: "set_debug_visible"
    - path: "world.gd"
      provides: "show_enemy_debug bool flag (default false), SHIFT+D edge-triggered handler that toggles the flag and applies it to every node in 'enemies' group, guard on plain-D unmount that ignores the press when SHIFT is held."
      contains: "show_enemy_debug"
    - path: "prefabs/ui/controls-hint.tscn"
      provides: "Cheatsheet line documenting SHIFT+D toggle."
      contains: "SHIFT+D"
  key_links:
    - from: "world.gd _input(event)"
      to: "EnemyShip.set_debug_visible(bool)"
      via: "get_tree().get_nodes_in_group('enemies') iteration on SHIFT+D edge press"
      pattern: "get_nodes_in_group\\(\"enemies\"\\)"
    - from: "EnemyShip._ready()"
      to: "components/enemy-ship.gd 'enemies' group + initial Shape.visible state"
      via: "add_to_group + assignment honoring world.show_enemy_debug if accessible, else default false"
      pattern: "add_to_group\\(\"enemies\"\\)"
    - from: "world.gd plain-D handler (line 349)"
      to: "guard against SHIFT-modified D press"
      via: "and not Input.is_key_pressed(KEY_SHIFT)"
      pattern: "KEY_D.*KEY_SHIFT|KEY_SHIFT.*KEY_D"
---

<objective>
Add a SHIFT+D toggle that swaps every enemy between "Sprite2D visible / Polygon2D Shape hidden" (default) and "Sprite2D hidden / Polygon2D Shape visible" (debug). The toggle must apply to currently-spawned enemies AND any enemies that spawn afterward, must NOT trigger the existing plain-D weapon unmount, and must default to sprites-on at game start.

Purpose: Restore on-demand access to the original Phase-15-era debug shapes for visual debugging without rolling back the sprite work.
Output: One-shot keybinding + group-based per-enemy visual toggle, controls-hint updated.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@components/enemy-ship.gd
@world.gd

<interfaces>
<!-- Key facts extracted from codebase. Use directly — do not re-explore. -->

From components/enemy-ship.gd:
```gdscript
class_name EnemyShip
extends Ship

func _ready() -> void:
    super()
    # ... detection_area / hitbox setup, then call_deferred("_setup_body_glow")

func _draw() -> void:
    # Skips drawing debug overlay when $Shape is hidden (sprite mode):
    var shape_node := get_node_or_null("Shape") as CanvasItem
    if shape_node and not shape_node.visible:
        return
    # ... otherwise draws cyan/red debug arcs, type label, state label, direction arrow
```

From per-enemy scripts (beeliner.gd, flanker.gd, sniper.gd, swarmer.gd, suicider.gd):
```gdscript
# Each enemy's _ready() calls _setup_sprite() which does:
func _setup_sprite() -> void:
    var atlas: Texture2D = load("res://ships_assests.png")
    if atlas == null:
        return  # SPR-03: atlas missing -> Polygon2D "Shape" stays visible (fallback)
    # ... set Sprite2D texture / region / scale / shader, then:
    $Shape.visible = false
```

From world.gd (line ~287 onward — _input handler):
```gdscript
func _input(event):
    if not $ShipBFG23: return
    # Mix of two patterns:
    #  (a) Input.is_key_pressed(KEY_X)              -- continuous (Q/W/E/1-6/A/S/D/G/H/J/R/C/I)
    #  (b) event is InputEventKey and event.pressed and event.keycode == KEY_X
    #                                               -- edge-triggered (ENTER/T/F/TAB)
    # Existing plain-D handler at line 349:
    if Input.is_key_pressed(KEY_D):
        $ShipBFG23.unmount_weapon("right")
```

From components/asteroid.gd line 5:
```gdscript
add_to_group("asteroid")  # group naming convention: lowercase, singular noun
```

Conflict: KEY_D is already bound to right-mount unmount. SHIFT+D must NOT fire that.
No "enemies" group exists yet -- must be added in EnemyShip._ready().
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add 'enemies' group + set_debug_visible() to EnemyShip and wire SHIFT+D toggle in world.gd</name>
  <files>components/enemy-ship.gd, world.gd, prefabs/ui/controls-hint.tscn</files>
  <action>
    Implement the toggle in three coordinated edits:

    **A. components/enemy-ship.gd**
    1. In `_ready()` (after `super()` and detection/hitbox setup, before `call_deferred("_setup_body_glow")`):
       - Add `add_to_group("enemies")`.
       - After group registration, query the world's current debug flag and apply it: `var world := get_tree().root.get_node_or_null("World"); var show_debug: bool = world.show_enemy_debug if world and "show_enemy_debug" in world else false; set_debug_visible(show_debug)`. Use `get_tree().current_scene` if `World` node name lookup is unreliable — pick whichever matches `world.tscn`'s root node name. (Verify by reading `world.tscn` first line if needed.)
       - This ensures (a) newly-spawned enemies join the group so the world toggle finds them, and (b) they adopt the current toggle state immediately at spawn — survives across waves per constraint.
    2. Add a new public method just below `_ready()`:
       ```gdscript
       # SHIFT+D debug visual toggle (quick task 260425-dnx).
       # show_debug=true  -> Polygon2D "Shape" visible, Sprite2D hidden, _draw() overlay enabled.
       # show_debug=false -> Sprite2D visible, Polygon2D "Shape" hidden, _draw() overlay skipped (per existing _draw guard).
       func set_debug_visible(show_debug: bool) -> void:
           var sprite_node := get_node_or_null("Sprite2D") as CanvasItem
           var shape_node := get_node_or_null("Shape") as CanvasItem
           if sprite_node:
               sprite_node.visible = not show_debug
           if shape_node:
               shape_node.visible = show_debug
           queue_redraw()  # _draw() reads $Shape.visible to decide whether to render overlays
       ```
       Function name `set_debug_visible` is snake_case per project convention. The `_draw()` guard at line 94-96 already keys off `$Shape.visible`, so toggling Shape correctly re-enables the cyan/red debug overlay too — no other change needed.

    **B. world.gd**
    1. Add a state flag near the other top-level vars (around line 37-43, with `godmode`, `camera_follow`, etc.):
       ```gdscript
       var show_enemy_debug: bool = false  # SHIFT+D toggle (quick task 260425-dnx)
       ```
    2. **Guard the existing plain-D unmount** (currently line 349 `if Input.is_key_pressed(KEY_D):`) so SHIFT+D never triggers it. Change that line to:
       ```gdscript
       if Input.is_key_pressed(KEY_D) and not Input.is_key_pressed(KEY_SHIFT):
           $ShipBFG23.unmount_weapon("right")
       ```
    3. Add a new edge-triggered handler in `_input(event)` near the other `event is InputEventKey ...` blocks (e.g. just before the TAB handler at line ~366). Use the edge pattern (NOT `Input.is_key_pressed`) so a single press toggles once instead of flipping every frame:
       ```gdscript
       # SHIFT+D: toggle enemy debug visuals (Polygon2D Shape vs Sprite2D). Quick task 260425-dnx.
       if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D and event.shift_pressed:
           show_enemy_debug = not show_enemy_debug
           for enemy in get_tree().get_nodes_in_group("enemies"):
               if enemy.has_method("set_debug_visible"):
                   enemy.set_debug_visible(show_enemy_debug)
           print("[world] enemy debug visuals: %s" % ("ON" if show_enemy_debug else "OFF"))
       ```
       The `not event.echo` filter prevents OS key-repeat from re-toggling.

    **C. prefabs/ui/controls-hint.tscn**
    1. Read the file, locate the existing `D - drop right mount` line (around line 73 per recon), and add a sibling line documenting the new shortcut. Match the existing line format/casing exactly. Suggested text: `SHIFT+D - toggle enemy debug visuals`. Place it adjacent to the `D - drop right mount` line for discoverability.
    2. If the controls hint uses a single `text` property on a Label node (typical), append `\nSHIFT+D - toggle enemy debug visuals` to that string. If it uses separate child labels, add a new label node following the same pattern as siblings.

    **Notes:**
    - Default state: `show_enemy_debug = false` means sprites visible / shapes hidden. EnemyShip._ready() applies this on spawn, so the .tscn's default `Shape` visibility is overridden — satisfies the "default sprites visible" constraint even though the .tscn currently has Shape visible.
    - The existing per-enemy `_setup_sprite()` already hides `$Shape` on successful atlas load; our toggle re-shows it. If atlas load fails (SPR-03 fallback path), Shape stays visible by default — set_debug_visible(false) will hide it, which is acceptable (player still sees no enemy at all in fallback, but that's an existing edge case unrelated to this task).
    - No new files. No scene changes beyond the controls hint label text.
  </action>
  <verify>
    <automated>cd /Users/milan.kormout/Projects/personal/graviton &amp;&amp; godot --headless --check-only --quit 2&gt;&amp;1 | grep -iE "error|parse" || echo "PARSE_OK"</automated>
  </verify>
  <done>
    - `components/enemy-ship.gd` contains `add_to_group("enemies")` in `_ready()` and a public `set_debug_visible(show_debug: bool) -> void` method.
    - EnemyShip._ready() applies `world.show_enemy_debug` (or `false` if unavailable) via `set_debug_visible()` so newly-spawned enemies inherit the current state.
    - `world.gd` declares `var show_enemy_debug: bool = false`.
    - `world.gd` plain-D handler is guarded by `and not Input.is_key_pressed(KEY_SHIFT)`.
    - `world.gd` has an edge-triggered SHIFT+D handler that flips the flag and iterates `get_tree().get_nodes_in_group("enemies")` calling `set_debug_visible()` on each.
    - `prefabs/ui/controls-hint.tscn` mentions `SHIFT+D` and describes the toggle.
    - `godot --check-only` passes (no parse errors).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Manual playtest of SHIFT+D toggle</name>
  <what-built>
    SHIFT+D toggle for enemy debug visuals (sprite vs Polygon2D shape) wired into world.gd, applied via EnemyShip 'enemies' group, with plain-D unmount preserved and controls-hint updated.
  </what-built>
  <how-to-verify>
    Open the project in the Godot 4.2.1 editor and run `world.tscn` (F5). Then:

    1. **Default state on game start**
       - Press F (or ENTER) to spawn the first wave.
       - Expected: enemies render with their Sprite2D atlas art; no red/cyan debug arcs, no type/state text labels.

    2. **First SHIFT+D press**
       - Hold SHIFT, tap D once, release.
       - Expected: every visible enemy switches — Sprite2D disappears, Polygon2D "Shape" appears, AND the red/cyan debug overlays + cyan type label + white STATE label + yellow direction arrow are drawn (because `_draw()`'s `$Shape.visible` guard now passes).
       - Console should print `[world] enemy debug visuals: ON`.

    3. **Second SHIFT+D press**
       - Hold SHIFT, tap D again.
       - Expected: enemies revert to Sprite2D visible / Shape + debug overlays hidden.
       - Console prints `[world] enemy debug visuals: OFF`.

    4. **Plain-D still unmounts the right weapon**
       - With NO SHIFT held, press D.
       - Expected: the right-side weapon detaches from the player ship (existing behavior). The debug toggle does NOT flip.

    5. **Toggle survives across waves (newly-spawned enemies)**
       - Toggle ON with SHIFT+D so debug shapes are visible.
       - Press F to clear/spawn the next wave (or wait for natural progression).
       - Expected: newly-spawned enemies appear in debug-shape mode (Polygon2D Shape visible, Sprite2D hidden, overlays drawn) WITHOUT pressing SHIFT+D again.
       - Toggle OFF with SHIFT+D, spawn another wave — new enemies appear in sprite mode.

    6. **Controls cheatsheet**
       - Press TAB to open the controls hint overlay.
       - Expected: a line mentioning `SHIFT+D` and the toggle is visible.

    7. **No key-repeat thrashing**
       - Hold SHIFT+D for ~1 second.
       - Expected: state flips exactly once (then `event.echo` prevents further flips). Console shows a single ON/OFF transition, not a stream.
  </how-to-verify>
  <resume-signal>Type "approved" if all 7 checks pass, or describe what failed (e.g. "step 4 failed — SHIFT+D also unmounted the right weapon").</resume-signal>
</task>

</tasks>

<verification>
- `godot --check-only` passes with no parse errors.
- All 7 manual playtest checks in Task 2 pass.
- No regression: existing weapon unmount on plain D still works; existing TAB/F/ENTER/T/G/H/J/R/C/I bindings unaffected.
</verification>

<success_criteria>
- SHIFT+D edge-triggers a global toggle of enemy visual mode.
- Default state at game start: sprites visible, debug shapes + overlays hidden.
- Toggle applies to currently-spawned AND future-spawned enemies (group + state-on-spawn pattern).
- Plain D continues to unmount the right-side weapon.
- Controls cheatsheet documents the new shortcut.
- No new files; minimal-diff edits to 3 existing files.
</success_criteria>

<output>
After completion, create `.planning/quick/260425-dnx-add-shift-d-toggle-to-switch-enemy-sprit/260425-dnx-SUMMARY.md` documenting:
- Final lines of code added/changed (with line numbers post-edit).
- The chosen approach for reading the world flag from EnemyShip._ready() (root node name vs current_scene).
- Result of the manual playtest (each of the 7 checks).
</output>
