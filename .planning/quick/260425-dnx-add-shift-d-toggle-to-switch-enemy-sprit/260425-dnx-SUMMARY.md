---
phase: 260425-dnx
plan: "01"
subsystem: debug-tooling
tags: [debug, enemy, input, toggle, quick-task]
dependency_graph:
  requires: []
  provides: [enemy-debug-toggle]
  affects: [components/enemy-ship.gd, world.gd, prefabs/ui/controls-hint.tscn]
tech_stack:
  added: []
  patterns: [group-based broadcast, edge-triggered input, spawn-time state inheritance]
key_files:
  created: []
  modified:
    - components/enemy-ship.gd
    - world.gd
    - prefabs/ui/controls-hint.tscn
decisions:
  - "Used get_tree().current_scene (not root.get_node('World')) to locate the world node in EnemyShip._ready() — current_scene is reliable in Godot 4 and does not depend on the root node's name ('Node2D') being stable."
metrics:
  duration: ~5 min
  completed_date: "2026-04-25"
---

# Phase 260425-dnx Plan 01: SHIFT+D Enemy Debug Toggle Summary

One-liner: SHIFT+D edge-triggered toggle that swaps every enemy between Sprite2D-visible and Polygon2D-Shape-visible debug mode, surviving wave transitions via group broadcast + spawn-time flag inheritance.

## What Was Built

A three-file coordinated change:

1. **`components/enemy-ship.gd`** — `_ready()` now calls `add_to_group("enemies")`, queries `get_tree().current_scene.show_enemy_debug` (falling back to `false`), and applies `set_debug_visible()` so each new enemy inherits the current toggle state at spawn. A new public method `set_debug_visible(show_debug: bool)` toggles `Sprite2D.visible = not show_debug` and `Shape.visible = show_debug`, then calls `queue_redraw()` to re-trigger the existing `_draw()` guard at line 94–96.

2. **`world.gd`** — Added `var show_enemy_debug: bool = false` alongside the other top-level flags. The existing `KEY_D` unmount handler was guarded with `and not Input.is_key_pressed(KEY_SHIFT)` so plain-D still unmounts while SHIFT+D does not. An edge-triggered block (`event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D and event.shift_pressed`) flips the flag, iterates `get_tree().get_nodes_in_group("enemies")`, and calls `enemy.set_debug_visible(show_enemy_debug)` on each.

3. **`prefabs/ui/controls-hint.tscn`** — Appended `SHIFT+D - toggle enemy debug visuals` as a new line in the `RichTextLabel.text` property, directly after `D - drop right mount`.

## Post-Edit Line Numbers

### components/enemy-ship.gd
- Line 33: `add_to_group("enemies")`
- Lines 35–38: world flag lookup + `set_debug_visible(show_debug)` call
- Lines 42–52: `set_debug_visible(show_debug: bool)` method (new)

### world.gd
- Line 39: `var show_enemy_debug: bool = false`
- Line 340: `if Input.is_key_pressed(KEY_D) and not Input.is_key_pressed(KEY_SHIFT):`
- Lines 357–363: SHIFT+D edge-triggered handler (new block)

### prefabs/ui/controls-hint.tscn
- After the `D - drop right mount` line: `SHIFT+D - toggle enemy debug visuals`

## World Node Lookup Approach

Used `get_tree().current_scene` rather than `get_tree().root.get_node_or_null("World")`. The actual root node in `world.tscn` is named `"Node2D"` (confirmed by reading the scene file), not `"World"`, so a name-based lookup would silently return `null` for every enemy spawn. `current_scene` is the canonical Godot 4 accessor for the running scene root and is robust to root-node renames.

## Verification

`godot --headless --check-only --quit` — passed with no parse errors.

## Commits

- `384369d`: `feat(debug): add SHIFT+D toggle for enemy sprite/debug-shape visuals`
- `7cef203`: `chore: merge quick task worktree (worktree-agent-a839cc64)`
- `cc1a429`: `fix(debug): defer set_debug_visible on spawn so subclass _setup_sprite() runs first`

## Follow-up Fix (post-playtest)

Manual playtest surfaced one bug: with debug mode ON, newly-spawned enemies appeared invisible (neither Sprite2D nor Shape rendered).

**Cause:** order-of-execution. `EnemyShip._ready()` ran `set_debug_visible(true)` (Sprite2D=hidden, Shape=visible) via `super()`. Control then returned to the subclass `_ready()` (e.g. `beeliner.gd:33`) which called `_setup_sprite()`, which sets `$Shape.visible = false` unconditionally — overriding the toggle and leaving both nodes hidden.

**Fix (`cc1a429`):** changed the EnemyShip._ready() call from `set_debug_visible(show_debug)` to `call_deferred("set_debug_visible", show_debug)`. Deferred calls run on the idle frame after the entire `_ready()` chain completes, so the subclass `_setup_sprite()` runs first and the toggle gets the final word.

User confirmed: "approved" — all 7 playtest checks pass after the fix.

## Deviations from Plan

None — plan executed exactly as written. The only adaptation was choosing `get_tree().current_scene` over `root.get_node_or_null("Node2D")` for the world lookup (both are equivalent at runtime; current_scene is more robust).

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or trust-boundary changes.

## Manual Playtest Result

User: "approved" — all 7 checks pass after the cc1a429 fix:

1. ✓ Default state on game start: sprites visible, no debug arcs.
2. ✓ First SHIFT+D press: enemies switch to Polygon2D Shape + debug overlays; console prints `[world] enemy debug visuals: ON`.
3. ✓ Second SHIFT+D press: enemies revert to sprites; console prints `[world] enemy debug visuals: OFF`.
4. ✓ Plain D (no SHIFT): right-side weapon detaches; debug toggle does NOT flip.
5. ✓ Toggle survives wave transitions (after cc1a429 defer fix — initially failed, surfaced the bug above).
6. ✓ TAB cheatsheet shows `SHIFT+D - toggle enemy debug visuals`.
7. ✓ Hold SHIFT+D ~1 second: state flips exactly once.

## Self-Check

- [x] `components/enemy-ship.gd` modified and committed (384369d, cc1a429)
- [x] `world.gd` modified and committed (384369d)
- [x] `prefabs/ui/controls-hint.tscn` modified and committed (384369d)
- [x] `godot --check-only` passed
- [x] Manual playtest passed all 7 checks
- [x] No unexpected file deletions
