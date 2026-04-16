---
phase: 14-enemy-balancing-wave-variety-ui-polish
plan: "04"
subsystem: ui-world
tags: [controls-hint, wave-pacing, keyboard-input, speed-tier, ui-toggle]
one_liner: "ControlsHint toggle panel (TAB + arrow button), gated wave-advance (ENTER/F), and Swarmer speed_tier fast/slow variants wired in world.gd"

dependency_graph:
  requires: [14-02, 14-03]
  provides:
    - "ControlsHint CanvasLayer with toggle() — hidden by default, TAB and arrow button"
    - "KEY_ENTER reassigned to gated wave-advance (no more asteroid spawn)"
    - "KEY_F gated to wave-advance when pending, fallback for first wave"
    - "KEY_TAB toggles controls-hint panel"
    - "wave_hud promoted to instance var _wave_hud for lifecycle access"
    - "Swarmer speed_tier variants: waves 5/16 fast (1.5), waves 10/18 slow (0.6), wave 12 both"
  affects:
    - prefabs/ui/controls-hint.gd
    - prefabs/ui/controls-hint.tscn
    - world.gd

tech_stack:
  added: []
  patterns:
    - "CanvasLayer + Button toggle pattern (matching DeathScreen)"
    - "Unicode triangle chars for arrow button (\\u25BA / \\u25C4)"
    - "Lambda func(_n) for signal connection with unused param"
    - "_wave_clear_pending bool flag for input gating"

key_files:
  created:
    - prefabs/ui/controls-hint.gd
  modified:
    - prefabs/ui/controls-hint.tscn
    - world.gd

decisions:
  - "KEY_F retains unconditional fallback (trigger_wave without pending) so first wave can still be started before any wave completes"
  - "ToggleButton placed as sibling of MarginContainer (not child) so it remains visible when panel is hidden"
  - "_wave_clear_pending reset on player death to prevent stale state after respawn/restart"
  - "controls_hint instantiated after death_screen to maintain consistent z-order"

metrics:
  duration_minutes: 12
  completed_date: "2026-04-16"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 2
  files_created: 1

status: COMPLETE
---

# Phase 14 Plan 04: Controls-Hint, Wave-Advance Gating, and Speed Tiers Summary

ControlsHint toggle panel (TAB + arrow button), gated wave-advance (ENTER/F), and Swarmer speed_tier fast/slow variants wired in world.gd.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create controls-hint.gd script and update controls-hint.tscn scene | 4b381ae | prefabs/ui/controls-hint.gd, prefabs/ui/controls-hint.tscn |
| 2 | Wire world.gd — KEY_ENTER/KEY_F wave-advance gating, KEY_TAB toggle, wave_hud promotion, controls_hint instantiation, speed_tier wave configs | e5c0a06 | world.gd |

## Task 3: Human Verification — PASSED

Human playtest confirmed all 15 verification points. Issues found and fixed during checkpoint:
- `\u` escape sequences in controls-hint.gd/.tscn replaced with `char(0x25BA/0x25C4)` and `">"` (GDScript does not support `\u` escapes)
- `Ship.pick_health()` regression restored — `ae45062` had accidentally reverted to `storage.add_item()`, now heals 10% of `max_health`
- Swarmer and Flanker Polygon2D rotation corrected from `-1.5708` to `+1.5708` (−90° points left, +90° points right)

## What Was Built

### Task 1: ControlsHint Script and Scene

**prefabs/ui/controls-hint.gd** (new file):
- `class_name ControlsHint extends CanvasLayer`
- `@onready var _panel_container: MarginContainer = $MarginContainer`
- `@onready var _toggle_button: Button = $ToggleButton`
- `_ready()`: sets `_panel_container.visible = false` (hidden by default, per D-04); connects `_toggle_button.pressed` to `toggle`
- `toggle()`: flips `_visible_state`, updates `_panel_container.visible`, sets button text to `◄` (panel visible) or `►` (panel hidden)

**prefabs/ui/controls-hint.tscn** (updated):
- Added `ext_resource` for the new script
- Root node `Controls-hint` now has `script = ExtResource("1_controls_hint")`
- Added `ToggleButton` node as sibling of `MarginContainer`, anchored to right screen edge (anchor_left=1.0, anchor_right=1.0), flat=true, initial text `►`
- Removed `unique_id` attributes from all nodes (editor artifacts)
- Updated RichTextLabel text with v3.0 shortcuts:
  - Added `Tab - cheat sheet` line
  - Changed `ENTER - asteroid spawn` → `F / Enter - next wave`
  - Shortened `G - god mode for current weapon` → `G - god mode for weapon`
  - Shortened `H - unlimited ammo, no reload` → `H - unlimited ammo`
  - Shortened `J  - no cooldown, maximum fire rate` → `J  - max fire rate`

### Task 2: world.gd Wiring

**prefabs/ui/controls-hint.tscn preload** added after `death_screen_model`.

**New instance variables** added after `var death_screen`:
- `var _wave_clear_pending: bool = false`
- `var _wave_hud: WaveHud = null`
- `var _controls_hint: ControlsHint = null`

**_ready() changes:**
- `wave_hud` local var promoted to `_wave_hud` instance var
- `wave_cleared_waiting` signal connected: `$WaveManager.wave_cleared_waiting.connect(func(_n): _wave_clear_pending = true)`
- `_controls_hint` instantiated and added as child after `death_screen`

**_input() changes:**
- `Input.is_key_pressed(KEY_ENTER)` + `spawn_asteroids(10)` removed
- New event-based `KEY_ENTER` handler: gated on `_wave_clear_pending` — calls `trigger_wave()` and `_wave_hud.hide_wave_clear_label()`
- `KEY_F` handler: gated path (pending) calls `trigger_wave()` + `hide_wave_clear_label()`; fallback path (not pending) calls `trigger_wave()` unconditionally for first wave
- New `KEY_TAB` handler: calls `_controls_hint.toggle()`

**Wave configs** — speed_tier variants added:
- Wave 5: "Fast Swarm" — swarmer group `speed_tier: 1.5`
- Wave 10: "Suiciders + Slow Swarm + Beelines" — swarmer group `speed_tier: 0.6`
- Wave 12: "Slow & Fast Swarm + Suiciders" — two swarmer groups: 5 at 0.6, 5 at 1.5
- Wave 16: "Fast Swarm + Suiciders + Snipers" — swarmer group `speed_tier: 1.5`
- Wave 18: "Snipers + Slow Swarm + Flankers" — swarmer group `speed_tier: 0.6`

**_on_player_died()** — resets `_wave_clear_pending = false` and calls `_wave_hud.hide_wave_clear_label()` before pausing tree.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All functionality is fully wired. Task 3 is a human verification checkpoint, not a code stub.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. Input gating (_wave_clear_pending) is a local boolean controlled by a trusted WaveManager signal.

## Self-Check: PASSED

- prefabs/ui/controls-hint.gd: FOUND (class_name ControlsHint, func toggle, _panel_container.visible = false)
- prefabs/ui/controls-hint.tscn: FOUND (ext_resource script, ToggleButton node, Tab - cheat sheet, F / Enter - next wave)
- world.gd: FOUND (controls_hint_model, _wave_clear_pending, _wave_hud, _controls_hint, KEY_TAB, KEY_ENTER gated, speed_tier in 6 wave groups, _on_player_died reset)
- Commit 4b381ae (Task 1): FOUND
- Commit e5c0a06 (Task 2): FOUND
