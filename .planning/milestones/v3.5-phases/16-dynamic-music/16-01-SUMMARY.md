---
phase: 16-dynamic-music
plan: 01
subsystem: audio
tags: [music, autoload, cross-fade, gdscript]
dependency_graph:
  requires:
    - music/*.mp3 (5 audio assets with loop=true import settings)
    - components/score-manager.gd (autoload pattern reference)
    - components/wave-manager.gd (wave_started signal source)
  provides:
    - MusicManager autoload (globally accessible via MusicManager singleton)
    - reset() method for Phase 17 game restart
  affects:
    - project.godot (new autoload entry)
    - world.gd (Plan 02 will add connect_to_wave_manager wiring)
tech_stack:
  added:
    - AudioStreamPlayer (dual-player ping-pong cross-fade pattern)
    - Tween.set_parallel(true) + chain().tween_callback() for simultaneous volume fade
  patterns:
    - ScoreManager autoload pattern (extends Node, call_deferred, connect_to_wave_manager)
    - Shuffle no-repeat track selection via Array.filter() + pick_random()
key_files:
  created:
    - components/music-manager.gd
  modified:
    - project.godot
decisions:
  - "Used var (not const) for _catalog dictionary to allow preload() at class scope (Pitfall 5 from RESEARCH.md)"
  - "Interrupt-and-swap strategy for mid-cross-fade category changes: kill active tween, call _finish_swap(), start new cross-fade immediately"
  - "Deferred initial playback via call_deferred('_start_playback') to avoid autoload-before-scene-tree issues"
  - "Player A starts at 0 dB (audible), Player B starts at -80 dB (silent) — roles swap after each cross-fade"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-17"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 1
requirements:
  - MUS-01
  - MUS-02
  - MUS-03
  - MUS-04
  - MUS-05
---

# Phase 16 Plan 01: MusicManager Autoload — Summary

**One-liner:** GDScript autoload with dual AudioStreamPlayer cross-fade, shuffle no-repeat track selection, and wave-threshold category resolution (ambient/combat/high_intensity).

## What Was Built

`components/music-manager.gd` — a script-only autoload registered in `project.godot` that:

- Starts ambient music immediately on game launch via `call_deferred("_start_playback")`
- Resolves the current music category from wave number: waves 1-5 → ambient, 6-10 → combat, 11+ → high_intensity
- Picks tracks using shuffle no-repeat: filters out the last-played track, falls back to full pool if only one track in category, and falls back to any available category if the category pool is empty
- Cross-fades between tracks using two `AudioStreamPlayer` nodes (A and B ping-pong) with a `Tween` that simultaneously fades A out (-80 dB) and B in (0 dB) over `crossfade_duration` seconds (default 2.0)
- Kills any in-progress tween before starting a new cross-fade, preventing volume accumulation on rapid category changes
- Exposes `reset()` for Phase 17 game restart: kills tween, stops both players, resets to ambient, starts a fresh track
- Exposes `connect_to_wave_manager(wm: Node)` — mirrors ScoreManager pattern; called by world.gd (Plan 02)

Preload catalog (6 preload calls across 3 categories):

| Category | Tracks |
|----------|--------|
| ambient | Gravity-Drum Choir.mp3, Sulfur Orbit.mp3 |
| combat | Static Lullaby.mp3, Gravimetric Dawn.mp3 |
| high_intensity | Static Lullaby.mp3, Gravimetric Dawn.mp3 |

`project.godot` — one line added to `[autoload]` section:
```
MusicManager="*res://components/music-manager.gd"
```

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Import MP3 files and set loop=true | (human action — no code commit) | music/*.import |
| 2 | Create MusicManager autoload script | 29bca7a | components/music-manager.gd |
| 3 | Register MusicManager autoload in project.godot | 0d8927a | project.godot |

## Deviations from Plan

None — plan executed exactly as written.

The preload catalog uses 5 unique MP3 filenames (the user confirmed 5 import files exist: Gravimetric Dawn, Graviton Lullaby, Gravity-Drum Choir, Static Lullaby, Sulfur Orbit). The catalog references 4 of these across 3 categories as specified in CONTEXT.md — this is correct per design.

## Known Stubs

None. MusicManager is self-contained. No data flows to UI. Plan 02 will wire it to WaveManager via world.gd.

## Threat Flags

None. All resource paths are hardcoded `res://` references. No user input reaches resource loading. Threat model T-16-01 and T-16-02 remain accepted as planned.

## Self-Check: PASSED

- components/music-manager.gd exists: FOUND
- project.godot contains MusicManager autoload: FOUND
- Commit 29bca7a exists: FOUND
- Commit 0d8927a exists: FOUND
- preload count = 6: CONFIRMED
- func reset() present: CONFIRMED
- func connect_to_wave_manager() present: CONFIRMED
