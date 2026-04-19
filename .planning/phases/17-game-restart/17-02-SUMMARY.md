---
phase: 17-game-restart
plan: "02"
subsystem: game-restart
tags: [death-screen, restart, world, signal, gdscript]
---

# Plan 17-02 Summary: Play Again Button + _restart_game()

## What Was Built

- Added `signal play_again_requested` to `DeathScreen` and dynamically creates a "Play Again" `Button` in `_on_submit()` (after name entry) — wired via `.pressed.connect()`
- `world.gd` connects `death_screen.play_again_requested` to `_restart_game()` in `_ready()`
- `_restart_game()` implements the full restart sequence: unpause → hide death screen → clear enemies/items/asteroids/explosions/bullets → `await process_frame` → reset `_wave_clear_pending` → instantiate new ship → reconnect all ship dependencies (camera, HUD, weapon HUD, coins, shake) → `ScoreManager.reset()` → `WaveManager.reset()` → `MusicManager.reset()` → `spawn_asteroids(10)`

## Requirements Satisfied

- UI-05: Play Again button present and clickable on death screen ✓
- UI-06: Restart clears enemies, resets wave to 1, restores player health ✓
- UI-07: Music resets to Ambient intensity via MusicManager.reset() ✓

## Key Decisions

- Button added dynamically in `_on_submit()` so it only appears after name submission, not before
- `await get_tree().process_frame` after queue_free calls prevents tree_exiting cascade from re-showing wave clear label
- Ship fully re-instantiated (not reset in place) to avoid stale signal connections
- `_wire_heavy_weapon_shake()` extracted as helper to avoid duplicate fired_heavy connections on restart
