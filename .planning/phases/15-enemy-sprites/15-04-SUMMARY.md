---
plan: 15-04
phase: 15-enemy-sprites
status: complete
completed: 2026-04-17
---

# Plan 15-04: Editor Verification and Visual Fixes — Summary

## Outcome: APPROVED

User opened the Godot editor, verified sprites, and issued `approved` resume signal.

## Fixes Applied During Checkpoint

| Issue | Fix | Files |
|-------|-----|-------|
| Runtime crash — `$Sprite2D` null | Added `Sprite2D` node to all 5 standalone enemy scenes | beeliner/sniper/flanker/swarmer/suicider .tscn |
| White background on sprites | Created `enemy-sprite.gdshader` — discards pixels with R/G/B > 0.92 | components/enemy-sprite.gdshader, all 5 enemy .gd |
| Ships facing wrong direction | Changed `rotation_degrees` from -90 to +90 in `_setup_sprite()` | all 5 enemy .gd |
| Debug overlays visible with sprite | `_draw()` returns early when `$Shape.visible == false` | components/enemy-ship.gd |
| Ships barely visible | Added `BodyGlow` PointLight2D (constant energy=0.4, 1.8× spread) | components/enemy-ship.gd |

## Final Values

Atlas Rect2 defaults remain as Plan 01 assumed values (user accepted visually).
Gem pulse parameters remain as Plan 01 defaults (user approved feel).
BodyGlow: energy=0.4, texture_scale=gem_scale×1.8, z_index=-1.
Shader threshold: 0.92 (safe for ENM-10 cream tones ~0.80).

## Verification Results

- SPR-01 ✓ All 5 enemy ships display atlas sprites
- SPR-02 ✓ Rect2 regions accepted by user
- SPR-03 ✓ Polygon2D fallback preserved; debug overlays shown when atlas missing
- SPR-04 ✓ GemLight pulses; BodyGlow provides constant ambient visibility
- SPR-05 ✓ Sprite scales accepted by user
- ships_assests.png.import ✓ Present
- Wave-20 FPS: not explicitly measured; shadow_enabled=false + VisibleOnScreenNotifier2D culling in place
- Rotation: +90° confirmed correct (noses face +X / look_at direction)

## Self-Check: PASSED
