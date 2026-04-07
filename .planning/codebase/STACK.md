# Technology Stack

**Analysis Date:** 2026-04-07

## Languages

**Primary:**
- GDScript - All game logic (`.gd` files throughout `components/`, `prefabs/`, `world.gd`)

**Secondary:**
- None detected

## Runtime

**Environment:**
- Godot Engine 4.2.1 (confirmed by `project.godot` `config/features=PackedStringArray("4.2", ...)` and CI image `barichello/godot-ci:4.2.1`)

**Package Manager:**
- None - Godot manages all engine dependencies internally; no external package manager

## Frameworks

**Core:**
- Godot 4.2.1 - Game engine; provides scene tree, physics, rendering, audio, input

**Testing:**
- None detected

**Build/Dev:**
- Godot headless CLI (`godot --headless --export-release`) - Used in CI for all platform builds
- `barichello/godot-ci:4.2.1` Docker image - CI build container

## Key Dependencies

**Critical:**
- Godot 4.2.1 engine - entire runtime; no standalone executable without engine export templates

**Built-in Godot Systems Used:**
- `RigidBody2D` - Physics-based movement for asteroids and ships (`components/asteroid.gd`, `components/body.gd`)
- `Node2D` - Base node for all 2D game objects
- `AudioStreamPlayer` / `RandomAudioPlayer` - Sound playback (`components/random-audio-player.gd`)
- `Camera2D` - Camera management (`components/body_camera.gd`)
- Godot Physics 2D - Custom gravity configuration (near-zero gravity: `2d/default_gravity=2.08165e-12` for space setting)
- Godot Resource system (`.tres`) - Item definitions for weapons and ammo

## Configuration

**Environment:**
- No `.env` files - all configuration is in `project.godot`
- Key settings: 1920x1080 viewport, maximized window (`mode=2`), max 100 FPS, black background

**Build:**
- `project.godot` - Engine project settings
- `export_presets.cfg` - Platform export configurations

## Rendering

**Renderer:** GL Compatibility (OpenGL-based, cross-platform)
- Mobile fallback: `gl_compatibility`
- VRAM compression: ETC2/ASTC enabled for mobile targets
- Max renderable lights: 128 (custom limit)
- Texture formats: BPTC, S3TC, ETC, ETC2

## Platform Requirements

**Development:**
- Godot 4.2.1 editor installed locally

**Production:**
- Export templates for each target platform (managed via CI)
- No external runtime dependencies beyond the exported binary

---

*Stack analysis: 2026-04-07*
